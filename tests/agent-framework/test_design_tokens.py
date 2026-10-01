"""Regression tests for the design-token per-platform generator."""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GENERATOR = REPO_ROOT / "scripts" / "agent-framework" / "design-tokens" / "generate.py"
TOKENS = REPO_ROOT / "agent-framework" / "design-system" / "tokens"
GENERATED = REPO_ROOT / "agent-framework" / "design-system" / "generated"


def run_generator(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GENERATOR), *args],
        cwd=REPO_ROOT,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=30,
    )


def import_generator():
    spec = importlib.util.spec_from_file_location("design_token_generator", GENERATOR)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


GENERATOR_MODULE = import_generator()


class TestDesignTokenGenerator(unittest.TestCase):
    def setUp(self) -> None:
        self.scratch = Path(tempfile.mkdtemp(prefix="design-token-test-"))

    def tearDown(self) -> None:
        shutil.rmtree(self.scratch, ignore_errors=True)

    def test_committed_artifacts_are_current_and_structurally_valid(self) -> None:
        result = run_generator("--check")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertRegex(result.stdout, r"current \(\d+ files\)")

        manifest = json.loads((GENERATED / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["sources"],
            [
                "tokens/base.json",
                "tokens/light.json",
                "tokens/dark.json",
                "tokens/high-contrast.json",
            ],
        )
        self.assertIn("web/tokens.css", manifest["files"])
        self.assertIn("web/tailwind.tokens.js", manifest["files"])
        self.assertIn("android/colors.xml", manifest["files"])
        self.assertIn("android/SkyPhoenixColors.kt", manifest["files"])
        self.assertIn("ios/Color+SkyPhoenix.swift", manifest["files"])
        self.assertIn("cli/ansi-colors.sh", manifest["files"])

        xml_root = ET.parse(GENERATED / "android" / "colors.xml").getroot()
        self.assertEqual(xml_root.tag, "resources")
        self.assertGreater(len(xml_root.findall("color")), 20)

        asset_json_files = sorted((GENERATED / "ios" / "Colors.xcassets").rglob("*.json"))
        self.assertGreater(len(asset_json_files), 20)
        for asset_file in asset_json_files:
            parsed = json.loads(asset_file.read_text(encoding="utf-8"))
            self.assertEqual(parsed["info"], {"author": "generated", "version": 1})

        css = (GENERATED / "web" / "tokens.css").read_text(encoding="utf-8")
        self.assertIn('[data-theme="light"]', css)
        self.assertIn('[data-theme="dark"]', css)
        self.assertIn('[data-theme="high-contrast"]', css)
        self.assertIn("status=proposed-derived", css)
        self.assertIn("resolved-from=brand.color.primary", css)
        self.assertIn("--semantic-color-cta-fill: #ed6d1f", css)
        self.assertIn("--semantic-color-cta-text-on-fill: #231815", css)
        self.assertIn(
            "token=semantic.color.cta-fill; source=design-system/tokens/base.json "
            "brand.color.logo-orange | design-system/cross-platform-standard.md section 1; "
            "status=approved-derived",
            css,
        )
        self.assertNotIn("token=semantic.color.cta-fill; source=design-system/tokens/base.json "
                         "brand.color.logo-orange | design-system/cross-platform-standard.md "
                         "section 1; status=extracted", css)

        android_names = {element.attrib["name"]: element.text for element in xml_root.findall("color")}
        self.assertEqual(android_names["light_semantic_color_cta_fill"], "#FFED6D1F")
        self.assertEqual(android_names["dark_semantic_color_cta_fill"], "#FFED6D1F")
        self.assertEqual(android_names["high_contrast_semantic_color_cta_fill"], "#FF1E3A5F")

        cta_asset = json.loads(
            (
                GENERATED
                / "ios"
                / "Colors.xcassets"
                / "SemanticColorCtaFill.colorset"
                / "Contents.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(len(cta_asset["colors"]), 4)
        self.assertEqual(
            cta_asset["colors"][2]["color"]["components"],
            {"alpha": "1.000", "blue": "0x5F", "green": "0x3A", "red": "0x1E"},
        )
        self.assertEqual(
            cta_asset["colors"][3]["appearances"],
            [
                {"appearance": "luminosity", "value": "dark"},
                {"appearance": "contrast", "value": "high"},
            ],
        )

        ansi = (GENERATED / "cli" / "ansi-colors.sh").read_text(encoding="utf-8")
        self.assertIn("LIGHT ONLY by design", ansi)
        self.assertNotIn("SKYPHOENIX_DARK_", ansi)
        self.assertNotIn("SKYPHOENIX_HIGH_CONTRAST_", ansi)
        self.assertIn("SKYPHOENIX_LIGHT_SEMANTIC_COLOR_CTA_FILL_COLOR256='\\033[38;5;208m'", ansi)

        node = shutil.which("node")
        if node is not None:
            tailwind = GENERATED / "web" / "tailwind.tokens.js"
            loaded = subprocess.run(
                [
                    node,
                    "-e",
                    (
                        "const t=require(process.argv[1]);"
                        "if(t.theme.extend.colors.cta!=='var(--semantic-color-cta-fill)')process.exit(2);"
                        "if(t.theme.extend.borderRadius.md!=='var(--radius-md)')process.exit(3);"
                        "if(!t.skyPhoenixTokens['high-contrast'])process.exit(4);"
                    ),
                    str(tailwind),
                ],
                cwd=REPO_ROOT,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(loaded.returncode, 0, loaded.stderr + loaded.stdout)

    def test_generation_is_byte_identical(self) -> None:
        first = self.scratch / "first"
        second = self.scratch / "second"
        for output in (first, second):
            result = run_generator("--output-dir", str(output))
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

        first_files = sorted(path.relative_to(first) for path in first.rglob("*") if path.is_file())
        second_files = sorted(path.relative_to(second) for path in second.rglob("*") if path.is_file())
        self.assertEqual(first_files, second_files)
        for relative_path in first_files:
            self.assertEqual(
                (first / relative_path).read_bytes(),
                (second / relative_path).read_bytes(),
                str(relative_path),
            )

    def test_check_mode_detects_content_and_file_set_drift(self) -> None:
        output = self.scratch / "generated"
        generated = run_generator("--output-dir", str(output))
        self.assertEqual(generated.returncode, 0, generated.stderr + generated.stdout)
        (output / "web" / "tokens.css").write_text("drift\n", encoding="utf-8")
        (output / "unexpected.txt").write_text("unexpected\n", encoding="utf-8")

        result = run_generator("--check", "--output-dir", str(output))
        self.assertEqual(result.returncode, 1)
        self.assertIn("generated file has drifted: web/tokens.css", result.stderr)
        self.assertIn("unexpected generated file: unexpected.txt", result.stderr)

    def test_missing_alias_fails_loudly(self) -> None:
        source = self._copy_tokens()
        light = json.loads((source / "light.json").read_text(encoding="utf-8"))
        light["semantic"]["color"]["brand-surface"]["$value"] = "{brand.color.missing}"
        (source / "light.json").write_text(json.dumps(light), encoding="utf-8")

        result = run_generator(
            "--source-dir", str(source), "--output-dir", str(self.scratch / "output")
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing alias {brand.color.missing}", result.stderr)
        self.assertFalse((self.scratch / "output").exists())

    def test_alias_cycle_fails_loudly(self) -> None:
        source = self._copy_tokens()
        base = json.loads((source / "base.json").read_text(encoding="utf-8"))
        base["brand"]["color"]["primary"]["$value"] = "{brand.color.secondary}"
        base["brand"]["color"]["secondary"]["$value"] = "{brand.color.primary}"
        (source / "base.json").write_text(json.dumps(base), encoding="utf-8")

        result = run_generator(
            "--source-dir", str(source), "--output-dir", str(self.scratch / "output")
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("alias cycle detected", result.stderr)
        self.assertIn("brand.color.primary", result.stderr)

    def test_invalid_color_fails_instead_of_inventing_a_fallback(self) -> None:
        source = self._copy_tokens()
        base = json.loads((source / "base.json").read_text(encoding="utf-8"))
        base["brand"]["color"]["primary"]["$value"] = "navy-ish"
        (source / "base.json").write_text(json.dumps(base), encoding="utf-8")

        result = run_generator(
            "--source-dir", str(source), "--output-dir", str(self.scratch / "output")
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsupported color value for brand.color.primary", result.stderr)

    def test_embedded_and_base_prefixed_aliases_resolve(self) -> None:
        tokens = {
            "raw.value": GENERATOR_MODULE.Token(
                path="raw.value",
                value="4px",
                token_type="dimension",
                source_file="fixture.json",
                sources=("fixture:1",),
                status="extracted",
            ),
            "alias.value": GENERATOR_MODULE.Token(
                path="alias.value",
                value="{base.raw.value}",
                token_type=None,
                source_file="fixture.json",
                sources=(),
                status="proposed-derived",
                references=("base.raw.value",),
            ),
            "embedded.value": GENERATOR_MODULE.Token(
                path="embedded.value",
                value="solid {raw.value}",
                token_type="string",
                source_file="fixture.json",
                sources=(),
                status="proposed-derived",
                references=("raw.value",),
            ),
        }
        resolved = GENERATOR_MODULE._resolve_tokens(tokens)
        self.assertEqual(resolved["alias.value"].value, "4px")
        self.assertEqual(resolved["alias.value"].token_type, "dimension")
        self.assertEqual(resolved["embedded.value"].value, "solid 4px")

    def test_token_level_status_overrides_document_status(self) -> None:
        tokens = GENERATOR_MODULE._collect(
            {
                "$status": "extracted",
                "semantic": {
                    "color": {
                        "cta": {
                            "$value": "#ed6d1f",
                            "$status": "approved-derived",
                        }
                    }
                },
            },
            "fixture.json",
        )
        self.assertEqual(tokens["semantic.color.cta"].status, "approved-derived")

    def _copy_tokens(self) -> Path:
        destination = self.scratch / "tokens"
        shutil.copytree(TOKENS, destination)
        return destination


if __name__ == "__main__":
    unittest.main()
