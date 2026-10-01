"""Local inline Markdown links in framework instructions (not code examples)."""
from __future__ import annotations

import os
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


LINK = re.compile(r'\[[^\]\n]*\]\(\s*(?P<target><[^>\n]+>|[^\s()\n]+)(?:\s+"[^"\n]*")?\s*\)')


def local_links(text: str):
    """Yield destination spans and paths; retain offsets for rebasing copies."""
    masked = re.sub(r'(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1\s*$',
                    lambda m: ' ' * len(m.group()), text)
    masked = re.sub(r'(`+).*?\1', lambda m: ' ' * len(m.group()), masked)
    for match in LINK.finditer(masked):
        value = text[match.start('target'):match.end('target')].strip('<>')
        url = urlsplit(value)
        if url.scheme or url.netloc or not url.path or url.path.startswith('/'):
            continue
        if any(char in url.path for char in ('*', '{', '}', '$')):
            continue  # illustrative placeholders are not resource references
        yield match.start('target'), match.end('target'), value, unquote(url.path)


def rebase_skill_links(text: str, source: Path, destination: Path,
                       skill_root: Path, repo_root: Path) -> str:
    """Bundled resources retain their links; external resources point to canonical."""
    replacements = []
    for start, end, value, path in local_links(text):
        resource = (source.parent / path).resolve()
        if not resource.is_relative_to(repo_root.resolve()):
            raise ValueError(f'local Markdown link escapes the repository: {path}')
        if resource.is_relative_to(skill_root.resolve()):
            continue
        new_path = Path(os.path.relpath(resource, destination.parent.resolve())).as_posix()
        suffix = value[len(urlsplit(value).path):]
        replacement = new_path + suffix
        if text[start:end].startswith('<') or ' ' in replacement:
            replacement = '<' + replacement + '>'
        replacements.append((start, end, replacement))
    for start, end, replacement in reversed(replacements):
        text = text[:start] + replacement + text[end:]
    return text


def invalid_local_links(text: str, document: Path, repo_root: Path) -> list[str]:
    invalid = []
    for _, _, value, path in local_links(text):
        target = (document.parent / path).resolve()
        if not target.is_relative_to(repo_root.resolve()) or not target.exists():
            invalid.append(value)
    return invalid
