#!/usr/bin/env python3
"""Generate deterministic per-platform artifacts from SKYPhoenix design tokens."""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Iterable


THEMES = ("light", "dark", "high-contrast")
ALIAS_RE = re.compile(r"\{([A-Za-z0-9_.-]+)\}")
HEX_RE = re.compile(r"^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
GENERATED_NOTICE = "GENERATED — DO NOT EDIT. Run scripts/agent-framework/design-tokens/generate.py."


class TokenGenerationError(ValueError):
    """The token graph or an output value is invalid."""


@dataclass(frozen=True)
class Token:
    path: str
    value: Any
    token_type: str | None
    source_file: str
    sources: tuple[str, ...]
    status: str
    references: tuple[str, ...] = ()

    @property
    def provenance(self) -> str:
        source = " | ".join(self.sources) if self.sources else self.source_file
        refs = f"; resolved-from={' | '.join(self.references)}" if self.references else ""
        return f"token={self.path}; source={source}; status={self.status}{refs}"

    @property
    def is_color(self) -> bool:
        return self.token_type == "color" or (
            self.path.startswith("semantic.color.")
            and isinstance(self.value, str)
            and HEX_RE.fullmatch(self.value) is not None
        )


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise TokenGenerationError(f"required token file is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise TokenGenerationError(f"invalid JSON in {path}: {error}") from error
    if not isinstance(value, dict):
        raise TokenGenerationError(f"token document must be an object: {path}")
    return value


def _walk_tokens(
    node: dict[str, Any],
    prefix: tuple[str, ...],
    source_file: str,
    status: str,
) -> Iterable[Token]:
    if "$value" in node:
        path = ".".join(prefix)
        if not path:
            raise TokenGenerationError(f"root token is not supported in {source_file}")
        extensions = node.get("$extensions", {})
        if extensions is None:
            extensions = {}
        if not isinstance(extensions, dict):
            raise TokenGenerationError(f"{source_file}:{path} has non-object $extensions")
        raw_sources = extensions.get("source", ())
        if isinstance(raw_sources, str):
            raw_sources = (raw_sources,)
        if not isinstance(raw_sources, (list, tuple)) or not all(
            isinstance(item, str) for item in raw_sources
        ):
            raise TokenGenerationError(f"{source_file}:{path} has invalid provenance source")
        token_status = node.get("$status", status)
        if not isinstance(token_status, str):
            raise TokenGenerationError(f"{source_file}:{path} has non-string $status")
        raw = node["$value"]
        references = tuple(ALIAS_RE.findall(raw)) if isinstance(raw, str) else ()
        yield Token(
            path=path,
            value=raw,
            token_type=node.get("$type"),
            source_file=source_file,
            sources=tuple(raw_sources),
            status=token_status,
            references=references,
        )
        return

    for key, value in node.items():
        if key.startswith("$"):
            continue
        if not isinstance(value, dict):
            raise TokenGenerationError(
                f"{source_file}:{'.'.join(prefix + (key,))} must be a token or group object"
            )
        yield from _walk_tokens(value, prefix + (key,), source_file, status)


def _collect(document: dict[str, Any], source_file: str) -> dict[str, Token]:
    status = document.get("$status", "extracted")
    if not isinstance(status, str):
        raise TokenGenerationError(f"{source_file} has non-string $status")
    result: dict[str, Token] = {}
    for token in _walk_tokens(document, (), source_file, status):
        if token.path in result:
            raise TokenGenerationError(f"duplicate token path: {source_file}:{token.path}")
        result[token.path] = token
    return result


def _resolve_alias_name(name: str, available: dict[str, Token], owner: str) -> str:
    candidates = (name, name.removeprefix("base."))
    for candidate in candidates:
        if candidate in available:
            return candidate
    raise TokenGenerationError(f"missing alias {{{name}}} referenced by {owner}")


def _resolve_tokens(tokens: dict[str, Token]) -> dict[str, Token]:
    resolved: dict[str, Token] = {}

    def resolve(path: str, stack: tuple[str, ...]) -> Token:
        if path in resolved:
            return resolved[path]
        if path in stack:
            cycle = " -> ".join(stack + (path,))
            raise TokenGenerationError(f"alias cycle detected: {cycle}")
        token = tokens[path]
        raw = token.value
        if not isinstance(raw, str) or not token.references:
            result = token
        else:
            exact = ALIAS_RE.fullmatch(raw)
            if exact:
                target_path = _resolve_alias_name(exact.group(1), tokens, path)
                target = resolve(target_path, stack + (path,))
                result = replace(
                    token,
                    value=target.value,
                    token_type=token.token_type or target.token_type,
                )
            else:
                value = raw
                for reference in token.references:
                    target_path = _resolve_alias_name(reference, tokens, path)
                    target = resolve(target_path, stack + (path,))
                    if isinstance(target.value, (dict, list)):
                        raise TokenGenerationError(
                            f"embedded alias {{{reference}}} in {path} resolves to a non-scalar value"
                        )
                    value = value.replace("{" + reference + "}", str(target.value))
                result = replace(token, value=value)
        resolved[path] = result
        return result

    for token_path in sorted(tokens):
        resolve(token_path, ())
    return resolved


def load_token_sets(source_dir: Path) -> tuple[dict[str, Token], dict[str, dict[str, Token]]]:
    base_file = source_dir / "base.json"
    base_raw = _collect(_read_json(base_file), "tokens/base.json")
    base = _resolve_tokens(base_raw)
    themes: dict[str, dict[str, Token]] = {}
    for theme in THEMES:
        filename = f"{theme}.json"
        theme_raw = _collect(_read_json(source_dir / filename), f"tokens/{filename}")
        combined = {**base_raw, **theme_raw}
        resolved_combined = _resolve_tokens(combined)
        themes[theme] = {path: resolved_combined[path] for path in theme_raw}
    return base, themes


def _segments(path: str) -> list[str]:
    return [part for part in re.split(r"[^A-Za-z0-9]+", path) if part]


def _kebab(path: str) -> str:
    return "-".join(part.lower() for part in _segments(path))


def _snake(path: str) -> str:
    return "_".join(part.lower() for part in _segments(path))


def _pascal(path: str) -> str:
    return "".join(part[:1].upper() + part[1:] for part in _segments(path))


def _lower_camel(path: str) -> str:
    pascal = _pascal(path)
    return pascal[:1].lower() + pascal[1:]


def _upper_snake(path: str) -> str:
    return "_".join(part.upper() for part in _segments(path))


def _comment_text(token: Token) -> str:
    return token.provenance.replace("\n", " ")


def _xml_comment_text(token: Token) -> str:
    # XML comments cannot contain "--". Retain the literal source text everywhere
    # else and use a visible, reversible separator only for this output format.
    return _comment_text(token).replace("--", "- -")


def _css_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    return str(value)


def _render_css_scope(selector: str, tokens: dict[str, Token], indent: str = "") -> list[str]:
    lines = [f"{indent}{selector} {{"]
    for path, token in sorted(tokens.items()):
        lines.append(f"{indent}  /* {_comment_text(token)} */")
        lines.append(f"{indent}  --{_kebab(path)}: {_css_value(token.value)};")
    lines.append(f"{indent}}}")
    return lines


def render_css(base: dict[str, Token], themes: dict[str, dict[str, Token]]) -> str:
    lines = [f"/* {GENERATED_NOTICE} */", ""]
    lines.extend(_render_css_scope(":root", base))
    for theme in THEMES:
        lines.extend([""] + _render_css_scope(f'[data-theme="{theme}"]', themes[theme]))
    lines.extend(["", "@media (prefers-color-scheme: light) {"])
    lines.extend(_render_css_scope(":root:not([data-theme])", themes["light"], "  "))
    lines.extend(["}", "", "@media (prefers-color-scheme: dark) {"])
    lines.extend(_render_css_scope(":root:not([data-theme])", themes["dark"], "  "))
    lines.extend(["}", "", "@media (prefers-contrast: more) {"])
    lines.extend(_render_css_scope(":root:not([data-theme])", themes["high-contrast"], "  "))
    lines.extend(["}", ""])
    return "\n".join(lines)


def render_tailwind(base: dict[str, Token], themes: dict[str, dict[str, Token]]) -> str:
    lines = [f"// {GENERATED_NOTICE}", "const skyPhoenixTokens = Object.freeze({"]
    groups = (("base", base),) + tuple((theme, themes[theme]) for theme in THEMES)
    for group, tokens in groups:
        lines.append(f"  {json.dumps(group)}: {{")
        for path, token in sorted(tokens.items()):
            lines.append(f"    // {_comment_text(token)}")
            lines.append(
                f"    {json.dumps(_kebab(path))}: {json.dumps(token.value, ensure_ascii=False)},"
            )
        lines.append("  },")
    lines.extend(["});", "", "module.exports = {"])
    lines.extend([
        "  // Colors resolve through generated CSS variables, so data-theme and system",
        "  // media-query changes do not require rebuilding Tailwind utilities.",
        "  theme: {",
        "    extend: {",
    ])

    extension_groups: tuple[tuple[str, str, Any, str], ...] = (
        ("colors", "brand.color.", lambda token: token.is_color, "brand-"),
        ("colors", "semantic.color.", lambda token: token.is_color, ""),
        ("borderRadius", "radius.", lambda token: token.token_type == "dimension", ""),
        ("borderWidth", "border.width-", lambda token: token.token_type == "dimension", ""),
        ("screens", "breakpoint.", lambda token: token.token_type == "dimension", ""),
        ("fontFamily", "font.family.", lambda token: token.token_type == "fontFamily", ""),
        ("fontSize", "font.size.", lambda token: token.token_type == "dimension", ""),
        ("fontWeight", "font.weight.", lambda token: token.token_type == "fontWeight", ""),
        ("spacing", "spacing.", lambda token: token.token_type == "dimension", ""),
        ("boxShadow", "shadow.", lambda token: token.token_type == "shadow", ""),
        (
            "transitionDuration",
            "motion.duration-",
            lambda token: token.token_type == "duration",
            "",
        ),
    )
    theme_paths = sorted(set().union(*(set(tokens) for tokens in themes.values())))
    extensions: dict[str, list[tuple[str, str, Token]]] = {}
    for extension_name, prefix, predicate, name_prefix in extension_groups:
        candidates: dict[str, Token] = {}
        if prefix == "semantic.color.":
            for path in theme_paths:
                if path.startswith(prefix):
                    representative = next(
                        (themes[theme][path] for theme in THEMES if path in themes[theme]), None
                    )
                    if representative is not None and predicate(representative):
                        candidates[path] = representative
        else:
            candidates = {
                path: token
                for path, token in base.items()
                if path.startswith(prefix) and predicate(token)
            }
        if not candidates:
            continue
        for path, token in sorted(candidates.items()):
            short_name = name_prefix + _kebab(path.removeprefix(prefix))
            if extension_name == "colors" and short_name == "cta-fill":
                short_name = "cta"
            elif extension_name == "colors" and short_name == "cta-text-on-fill":
                short_name = "cta-on-fill"
            entries = extensions.setdefault(extension_name, [])
            if any(existing_name == short_name for existing_name, _, _ in entries):
                raise TokenGenerationError(
                    f"Tailwind {extension_name} key collision: {short_name}"
                )
            entries.append((short_name, path, token))

    for extension_name, entries in extensions.items():
        lines.append(f"      {extension_name}: {{")
        for short_name, path, token in entries:
            lines.append(f"        // {_comment_text(token)}")
            lines.append(f'        {json.dumps(short_name)}: "var(--{_kebab(path)})",')
        lines.append("      },")
    lines.extend([
        "    },",
        "  },",
        "  // Complete resolved values and status/provenance comments remain available",
        "  // for tooling that needs more than Tailwind's supported theme-extension shapes.",
        "  skyPhoenixTokens,",
        "};",
        "",
    ])
    return "\n".join(lines)


def _parse_hex(value: Any, token: Token) -> tuple[int, int, int, int]:
    if not isinstance(value, str) or HEX_RE.fullmatch(value) is None:
        raise TokenGenerationError(f"unsupported color value for {token.path}: {value!r}")
    digits = value[1:]
    red, green, blue = (int(digits[index:index + 2], 16) for index in (0, 2, 4))
    alpha = int(digits[6:8], 16) if len(digits) == 8 else 255
    return red, green, blue, alpha


def _color_tokens(tokens: dict[str, Token]) -> dict[str, Token]:
    return {path: token for path, token in tokens.items() if token.is_color}


def render_android_xml(base: dict[str, Token], themes: dict[str, dict[str, Token]]) -> str:
    lines = [f"<!-- {GENERATED_NOTICE} -->", "<resources>"]
    groups = (("base", base),) + tuple((theme, themes[theme]) for theme in THEMES)
    for group, tokens in groups:
        for path, token in sorted(_color_tokens(tokens).items()):
            red, green, blue, alpha = _parse_hex(token.value, token)
            lines.append(f"    <!-- {_xml_comment_text(token)} -->")
            lines.append(
                f'    <color name="{_snake(group + "." + path)}">'
                f"#{alpha:02X}{red:02X}{green:02X}{blue:02X}</color>"
            )
    lines.extend(["</resources>", ""])
    output = "\n".join(lines)
    ET.fromstring(output)
    return output


def render_compose(base: dict[str, Token], themes: dict[str, dict[str, Token]]) -> str:
    lines = [
        f"// {GENERATED_NOTICE}",
        "package com.skyphoenix.designsystem.generated",
        "",
        "import androidx.compose.ui.graphics.Color",
        "",
        "object SkyPhoenixColors {",
    ]
    groups = (("base", base),) + tuple((theme, themes[theme]) for theme in THEMES)
    for group, tokens in groups:
        lines.append(f"    object {_pascal(group)} {{")
        for path, token in sorted(_color_tokens(tokens).items()):
            red, green, blue, alpha = _parse_hex(token.value, token)
            lines.append(f"        // {_comment_text(token)}")
            lines.append(
                f"        val {_pascal(path)} = Color(0x{alpha:02X}{red:02X}{green:02X}{blue:02X})"
            )
        lines.append("    }")
        lines.append("")
    lines.extend([
        "    // Material3 role mapping is intentionally not generated: it requires an explicit product decision.",
        "}",
        "",
    ])
    return "\n".join(lines)


def _ios_color_entry(token: Token, appearances: list[dict[str, str]] | None = None) -> dict[str, Any]:
    red, green, blue, alpha = _parse_hex(token.value, token)
    entry: dict[str, Any] = {
        "$comment": _comment_text(token),
        "idiom": "universal",
        "color": {
            "color-space": "srgb",
            "components": {
                "red": f"0x{red:02X}",
                "green": f"0x{green:02X}",
                "blue": f"0x{blue:02X}",
                "alpha": f"{alpha / 255:.3f}",
            },
        },
    }
    if appearances:
        entry["appearances"] = appearances
    return entry


def _asset_contents(entries: list[dict[str, Any]]) -> str:
    payload = {
        "$comment": GENERATED_NOTICE,
        "colors": entries,
        "info": {"author": "generated", "version": 1},
    }
    return json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def render_ios(
    base: dict[str, Token], themes: dict[str, dict[str, Token]]
) -> tuple[dict[str, str], list[tuple[str, str, Token]]]:
    files: dict[str, str] = {
        "ios/Colors.xcassets/Contents.json": json.dumps(
            {"$comment": GENERATED_NOTICE, "info": {"author": "generated", "version": 1}},
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        ) + "\n"
    }
    swift_assets: list[tuple[str, str, Token]] = []

    for path, token in sorted(_color_tokens(base).items()):
        asset = _pascal(path)
        files[f"ios/Colors.xcassets/{asset}.colorset/Contents.json"] = _asset_contents(
            [_ios_color_entry(token)]
        )
        swift_assets.append((_lower_camel(path), asset, token))

    color_sets = {theme: _color_tokens(themes[theme]) for theme in THEMES}
    common = set(color_sets["light"]) & set(color_sets["dark"]) & set(color_sets["high-contrast"])
    for path in sorted(common):
        light = color_sets["light"][path]
        dark = color_sets["dark"][path]
        contrast = color_sets["high-contrast"][path]
        asset = _pascal(path)
        entries = [
            _ios_color_entry(light),
            _ios_color_entry(dark, [{"appearance": "luminosity", "value": "dark"}]),
            _ios_color_entry(contrast, [{"appearance": "contrast", "value": "high"}]),
            _ios_color_entry(
                contrast,
                [
                    {"appearance": "luminosity", "value": "dark"},
                    {"appearance": "contrast", "value": "high"},
                ],
            ),
        ]
        files[f"ios/Colors.xcassets/{asset}.colorset/Contents.json"] = _asset_contents(entries)
        swift_assets.append((_lower_camel(path), asset, light))

    for theme in THEMES:
        for path in sorted(set(color_sets[theme]) - common):
            token = color_sets[theme][path]
            prefix = _pascal(theme)
            asset = prefix + _pascal(path)
            files[f"ios/Colors.xcassets/{asset}.colorset/Contents.json"] = _asset_contents(
                [_ios_color_entry(token)]
            )
            swift_assets.append((_lower_camel(theme) + _pascal(path), asset, token))

    return files, sorted(swift_assets)


def render_swift(assets: list[tuple[str, str, Token]]) -> str:
    lines = [
        f"// {GENERATED_NOTICE}",
        "import SwiftUI",
        "",
        "public extension Color {",
    ]
    for property_name, asset_name, token in assets:
        lines.append(f"    // {_comment_text(token)}")
        lines.append(f'    static let {property_name} = Color("{asset_name}")')
    lines.extend(["}", ""])
    return "\n".join(lines)


def _xterm_palette() -> list[tuple[int, int, int]]:
    base = [
        (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0),
        (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0),
        (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    ]
    cube = [0, 95, 135, 175, 215, 255]
    colors = base + [(red, green, blue) for red in cube for green in cube for blue in cube]
    colors.extend((level, level, level) for level in range(8, 239, 10))
    return colors


XTERM_PALETTE = _xterm_palette()


def _nearest_xterm(red: int, green: int, blue: int) -> int:
    return min(
        range(len(XTERM_PALETTE)),
        key=lambda index: sum(
            (actual - wanted) ** 2
            for actual, wanted in zip(XTERM_PALETTE[index], (red, green, blue), strict=True)
        ),
    )


DOCUMENTED_XTERM_FALLBACKS = {
    "brand.color.primary": 24,
    "brand.color.logo-orange": 208,
    "semantic.color.cta-fill": 208,
    "semantic.color.danger": 196,
    "semantic.color.success-text": 22,
    "semantic.color.warning-text": 130,
    "semantic.color.info-text": 25,
}


def _xterm_index(token: Token, red: int, green: int, blue: int) -> int:
    # The standard's representative semantic fallbacks are deliberate rather than
    # Euclidean RGB matches (navy/orange are the important examples). New colors use
    # deterministic nearest-palette matching until a reviewed semantic mapping exists.
    return DOCUMENTED_XTERM_FALLBACKS.get(token.path, _nearest_xterm(red, green, blue))


def _ansi16(red: int, green: int, blue: int) -> int:
    maximum = max(red, green, blue)
    minimum = min(red, green, blue)
    if maximum - minimum < 32:
        return 97 if maximum >= 192 else (37 if maximum >= 96 else 30)
    if red >= blue and green >= blue and red > 1.35 * blue and green > 0.35 * red:
        return 33  # Orange/yellow has no 16-color slot; yellow is the documented fallback.
    if red >= green and red >= blue:
        return 31
    if green >= red and green >= blue:
        return 36 if blue > 0.65 * green else 32
    return 35 if red > 0.65 * blue else 34


def render_ansi(base: dict[str, Token], light: dict[str, Token]) -> str:
    lines = [
        f"# {GENERATED_NOTICE}",
        "# LIGHT ONLY by design: terminals own their palette and expose no reliable app-theme signal.",
        "# Consumers must honor NO_COLOR and TERM=dumb before applying these escape sequences.",
        "# Color must never be the only channel for status or meaning.",
        "",
        "readonly SKYPHOENIX_ANSI_RESET='\\033[0m'",
    ]
    for group, tokens in (("base", base), ("light", light)):
        for path, token in sorted(_color_tokens(tokens).items()):
            red, green, blue, _ = _parse_hex(token.value, token)
            name = f"SKYPHOENIX_{_upper_snake(group + '.' + path)}"
            lines.extend([
                f"# {_comment_text(token)}",
                f"readonly {name}_TRUECOLOR='\\033[38;2;{red};{green};{blue}m'",
                f"readonly {name}_COLOR256='\\033[38;5;{_xterm_index(token, red, green, blue)}m'",
                f"readonly {name}_COLOR16='\\033[{_ansi16(red, green, blue)}m'",
            ])
    lines.append("")
    return "\n".join(lines)


def build_artifacts(source_dir: Path) -> dict[str, bytes]:
    base, themes = load_token_sets(source_dir)
    ios_files, swift_assets = render_ios(base, themes)
    files = {
        "web/tokens.css": render_css(base, themes),
        "web/tailwind.tokens.js": render_tailwind(base, themes),
        "android/colors.xml": render_android_xml(base, themes),
        "android/SkyPhoenixColors.kt": render_compose(base, themes),
        "ios/Color+SkyPhoenix.swift": render_swift(swift_assets),
        "cli/ansi-colors.sh": render_ansi(base, themes["light"]),
        **ios_files,
    }
    manifest = {
        "$comment": GENERATED_NOTICE,
        "sources": ["tokens/base.json", *[f"tokens/{theme}.json" for theme in THEMES]],
        "files": sorted(files),
    }
    files["manifest.json"] = json.dumps(
        manifest, ensure_ascii=False, indent=2, sort_keys=True
    ) + "\n"
    return {path: content.encode("utf-8") for path, content in sorted(files.items())}


def _actual_files(output_dir: Path) -> set[str]:
    if not output_dir.exists():
        return set()
    return {
        str(path.relative_to(output_dir))
        for path in output_dir.rglob("*")
        if path.is_file()
    }


def check_artifacts(output_dir: Path, expected: dict[str, bytes]) -> list[str]:
    problems: list[str] = []
    expected_paths = set(expected)
    actual_paths = _actual_files(output_dir)
    for path in sorted(expected_paths - actual_paths):
        problems.append(f"missing generated file: {path}")
    for path in sorted(actual_paths - expected_paths):
        problems.append(f"unexpected generated file: {path}")
    for path in sorted(expected_paths & actual_paths):
        if (output_dir / path).read_bytes() != expected[path]:
            problems.append(f"generated file has drifted: {path}")
    return problems


def write_artifacts(output_dir: Path, expected: dict[str, bytes]) -> None:
    for relative_path, content in expected.items():
        destination = output_dir / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)


def parse_args(argv: list[str]) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=repo_root / "agent-framework" / "design-system" / "tokens",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=repo_root / "agent-framework" / "design-system" / "generated",
    )
    parser.add_argument("--check", action="store_true", help="fail if committed artifacts drift")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        expected = build_artifacts(args.source_dir)
        if args.check:
            problems = check_artifacts(args.output_dir, expected)
            if problems:
                for problem in problems:
                    print(f"ERROR: {problem}", file=sys.stderr)
                print(
                    "ERROR: regenerate with scripts/agent-framework/design-tokens/generate.py",
                    file=sys.stderr,
                )
                return 1
            print(f"design-token artifacts are current ({len(expected)} files)")
            return 0
        write_artifacts(args.output_dir, expected)
        print(f"generated {len(expected)} design-token artifacts in {args.output_dir}")
        return 0
    except TokenGenerationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
