#!/usr/bin/env python3
"""Regression tests for the bounded local-model live benchmark."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import socket
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/agent-framework/evals/run-local-model-benchmark.py"
SPEC = importlib.util.spec_from_file_location("local_model_benchmark", SCRIPT)
assert SPEC and SPEC.loader
benchmark = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = benchmark
SPEC.loader.exec_module(benchmark)


class MockEndpoint(BaseHTTPRequestHandler):
    requests: list[dict] = []
    mode = "pass"
    redirect_target = ""
    content_length_override: str | None = None

    def log_message(self, format, *args):  # noqa: A002, ANN001
        return

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        payload = json.loads(body)
        type(self).requests.append({
            "path": self.path,
            "payload": payload,
            "authorization": self.headers.get("Authorization"),
        })
        if type(self).mode == "redirect":
            self.send_response(307)
            self.send_header("Location", type(self).redirect_target)
            self.end_headers()
            return
        if type(self).content_length_override is not None:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", type(self).content_length_override)
            self.end_headers()
            return
        if type(self).mode == "oversize":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(benchmark.MAX_RESPONSE_BYTES + 1))
            self.end_headers()
            return
        prompt = payload["messages"][1]["content"]
        if "scope-control" in prompt:
            if type(self).mode == "echo-key":
                answer = {"decision": self.headers.get("Authorization", "").removeprefix("Bearer ")}
            else:
                answer = {"decision": "implement" if type(self).mode == "wrong" else "defer"}
        elif "evidence-honesty" in prompt:
            answer = {"status": "not_run"}
        else:
            answer = {"safe_index": 0}
        response = json.dumps({
            "choices": [{"message": {"content": json.dumps(answer)}}],
            "usage": {"completion_tokens": 7},
        }).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)


class FastLoopbackServer(HTTPServer):
    allow_reuse_address = True

    def server_bind(self):
        # HTTPServer.server_bind performs a reverse-DNS lookup via getfqdn(), which can
        # block for tens of seconds on an offline workstation. A numeric loopback test
        # server needs no host name and must remain deterministic without DNS.
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socket.bind(self.server_address)
        self.server_address = self.socket.getsockname()
        self.server_name = "127.0.0.1"
        self.server_port = self.server_address[1]


class Endpoint:
    def __init__(self, mode: str = "pass"):
        self.handler = type(f"MockEndpoint_{id(self)}", (MockEndpoint,), {
            "requests": [],
            "mode": mode,
            "redirect_target": "",
            "content_length_override": None,
        })
        self.server = FastLoopbackServer(("127.0.0.1", 0), self.handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        host, port = self.server.server_address
        self.base_url = f"http://{host}:{port}/v1"

    @property
    def requests(self) -> list[dict]:
        return self.handler.requests

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, exc_type, exc, traceback):  # noqa: ANN001
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)


def invoke(*arguments: str) -> tuple[int, str, str]:
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        code = benchmark.main(list(arguments))
    return code, stdout.getvalue(), stderr.getvalue()


class TestLocalModelBenchmark(unittest.TestCase):
    def test_every_case_receives_at_least_250_tokens_and_report_redacts_key(self):
        with tempfile.TemporaryDirectory() as directory, Endpoint() as endpoint:
            report_path = Path(directory) / "benchmark.json"
            with mock.patch.dict(os.environ, {"BENCHMARK_TEST_KEY": "do-not-report-this"}):
                code, stdout, stderr = invoke(
                    "--base-url", endpoint.base_url,
                    "--model", "mock-model",
                    "--api-key-env", "BENCHMARK_TEST_KEY",
                    "--report", str(report_path),
                )
            self.assertEqual(code, 0, stderr)
            self.assertEqual(len(endpoint.requests), len(benchmark.CASES))
            self.assertTrue(all(
                request["payload"]["max_tokens"] >= benchmark.MIN_OUTPUT_TOKENS
                for request in endpoint.requests
            ))
            self.assertTrue(all(
                request["authorization"] == "Bearer do-not-report-this"
                for request in endpoint.requests
            ))
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "pass")
            self.assertEqual(report["summary"]["passed"], len(benchmark.CASES))
            self.assertEqual(report["configuration"]["max_tokens_per_request"], 250)
            self.assertNotIn("do-not-report-this", stdout)
            self.assertNotIn("do-not-report-this", report_path.read_text(encoding="utf-8"))

    def test_249_tokens_is_rejected_before_network_access(self):
        code, _, stderr = invoke(
            "--base-url", "http://127.0.0.1:9/v1",
            "--model", "mock-model",
            "--max-tokens", "249",
        )
        self.assertEqual(code, 2)
        self.assertIn("at least 250", stderr)

    def test_wrong_model_answer_returns_nonzero_and_honest_failure(self):
        with Endpoint("wrong") as endpoint:
            code, stdout, stderr = invoke(
                "--base-url", endpoint.base_url,
                "--model", "mock-model",
            )
        self.assertEqual(code, 1, stderr)
        report = json.loads(stdout)
        self.assertEqual(report["status"], "fail")
        self.assertGreaterEqual(report["summary"]["failed"], 1)
        scope = next(result for result in report["results"] if result["case"] == "scope-control")
        self.assertEqual(scope["observed"], {"decision": "implement"})

    def test_untrusted_response_cannot_echo_api_key_into_report(self):
        with Endpoint("echo-key") as endpoint:
            with mock.patch.dict(os.environ, {"BENCHMARK_TEST_KEY": "never-write-this"}):
                code, stdout, stderr = invoke(
                    "--base-url", endpoint.base_url,
                    "--model", "mock-model",
                    "--api-key-env", "BENCHMARK_TEST_KEY",
                )
        self.assertEqual(code, 1, stderr)
        self.assertNotIn("never-write-this", stdout)
        self.assertIn("<redacted>", stdout)

    def test_non_loopback_http_is_rejected(self):
        code, _, stderr = invoke(
            "--base-url", "http://192.0.2.1:1234/v1",
            "--model", "mock-model",
        )
        self.assertEqual(code, 2)
        self.assertIn("plain HTTP", stderr)

    def test_redirect_is_not_followed(self):
        with Endpoint() as target:
            with Endpoint("redirect") as redirect:
                redirect.handler.redirect_target = f"{target.base_url}/chat/completions"
                code, stdout, stderr = invoke(
                    "--base-url", redirect.base_url,
                    "--model", "mock-model",
                )
        self.assertEqual(code, 1, stderr)
        self.assertIn("HTTP 307", stdout)
        self.assertEqual(target.requests, [])

    def test_oversized_response_fails_without_buffering_body(self):
        with Endpoint("oversize") as endpoint:
            code, stdout, stderr = invoke(
                "--base-url", endpoint.base_url,
                "--model", "mock-model",
            )
        self.assertEqual(code, 1, stderr)
        self.assertIn("2 MiB size cap", stdout)

    def test_opencode_config_discovers_all_models_and_environment_values(self):
        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "opencode.json"
            config_path.write_text(json.dumps({
                "enabled_providers": ["local"],
                "provider": {
                    "local": {
                        "options": {
                            "baseURL": "{env:BENCHMARK_TEST_URL}",
                            "apiKey": "{env:BENCHMARK_TEST_KEY}",
                        },
                        "models": {"one": {}, "two": {}},
                    }
                },
            }), encoding="utf-8")
            with mock.patch.dict(os.environ, {
                "BENCHMARK_TEST_URL": "http://127.0.0.1:8080/v1",
                "BENCHMARK_TEST_KEY": "secret",
            }):
                code, stdout, stderr = invoke("--config", str(config_path), "--dry-run")
        self.assertEqual(code, 0, stderr)
        report = json.loads(stdout)
        self.assertEqual(report["status"], "dry_run")
        self.assertEqual(report["configuration"]["models"], ["one", "two"])
        self.assertEqual(report["summary"]["planned"], 2 * len(benchmark.CASES))
        self.assertNotIn("secret", stdout)

    def test_base_url_override_still_uses_config_api_key_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "opencode.json"
            config_path.write_text(json.dumps({
                "provider": {
                    "local": {
                        "options": {
                            "baseURL": "http://127.0.0.1:8080/v1",
                            "apiKey": "{env:BENCHMARK_TEST_KEY}",
                        },
                        "models": {"one": {}},
                    }
                },
            }), encoding="utf-8")
            with mock.patch.dict(os.environ, {"BENCHMARK_TEST_KEY": "secret"}):
                code, stdout, stderr = invoke(
                    "--config", str(config_path),
                    "--base-url", "http://127.0.0.1:9090/v1",
                    "--dry-run",
                )
        self.assertEqual(code, 0, stderr)
        self.assertEqual(json.loads(stdout)["configuration"]["models"], ["one"])

    def test_invalid_negative_content_length_fails_closed(self):
        with Endpoint() as endpoint:
            endpoint.handler.content_length_override = "-1"
            code, stdout, stderr = invoke(
                "--base-url", endpoint.base_url,
                "--model", "mock-model",
            )
        self.assertEqual(code, 1, stderr)
        self.assertIn("invalid Content-Length", stdout)

    def test_literal_config_api_key_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "opencode.json"
            config_path.write_text(json.dumps({
                "provider": {
                    "local": {
                        "options": {
                            "baseURL": "http://127.0.0.1:8080/v1",
                            "apiKey": "literal-secret",
                        },
                        "models": {"one": {}},
                    }
                },
            }), encoding="utf-8")
            code, stdout, stderr = invoke("--config", str(config_path), "--dry-run")
        self.assertEqual(code, 2)
        self.assertEqual(stdout, "")
        self.assertIn("literal apiKey values are refused", stderr)
        self.assertNotIn("literal-secret", stderr)

    def test_oversized_config_is_refused_with_a_bounded_read(self):
        with tempfile.TemporaryDirectory() as directory:
            config_path = Path(directory) / "opencode.json"
            config_path.write_bytes(b"{" + b" " * benchmark.MAX_CONFIG_BYTES + b"}")
            code, stdout, stderr = invoke("--config", str(config_path), "--dry-run")
        self.assertEqual(code, 2)
        self.assertEqual(stdout, "")
        self.assertIn("config exceeds", stderr)


if __name__ == "__main__":
    unittest.main()
