#!/usr/bin/env python3
"""Checks that every relative link in the repository's Markdown files resolves.

Verifies that linked files exist and that `#anchors` match a heading in the
target file, using the same slug rules GitHub applies. External links
(http/https/mailto) are not fetched. Links inside fenced code blocks are
ignored.

Usage: tool/check_docs_links.py   (exit code 1 when a broken link is found)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".dart_tool", "build", "node_modules", ".fvm"}

INLINE_LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
IMAGE_LINK = re.compile(r"!\[[^\]]*\]\(([^)\s]+)\)")
REF_DEFINITION = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)", re.MULTILINE)
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")


def markdown_files() -> list[Path]:
    return sorted(
        p
        for p in ROOT.rglob("*.md")
        if not any(part in SKIP_DIRS for part in p.relative_to(ROOT).parts)
    )


def strip_code_blocks(text: str) -> str:
    """Blanks fenced code blocks so links inside them are not checked."""
    out, in_fence = [], False
    for line in text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return "\n".join(out)


def heading_text(raw: str) -> str:
    """Approximates the rendered text of a heading (links and code removed)."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", raw)
    text = re.sub(r"!?\[([^\]]*)\]\[[^\]]*\]", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"<[^>]+>", "", text)
    return text


def github_slug(text: str) -> str:
    slug = heading_text(text).strip().lower()
    slug = re.sub(r"[^\w\- ]", "", slug)
    return slug.replace(" ", "-")


def anchors_of(path: Path, cache: dict[Path, set[str]]) -> set[str]:
    if path not in cache:
        seen: dict[str, int] = {}
        anchors: set[str] = set()
        for line in strip_code_blocks(path.read_text(encoding="utf-8")).splitlines():
            match = HEADING.match(line)
            if not match:
                continue
            slug = github_slug(match.group(2))
            count = seen.get(slug, 0)
            anchors.add(slug if count == 0 else f"{slug}-{count}")
            seen[slug] = count + 1
        cache[path] = anchors
    return cache[path]


def check() -> int:
    cache: dict[Path, set[str]] = {}
    errors: list[str] = []
    for md in markdown_files():
        text = strip_code_blocks(md.read_text(encoding="utf-8"))
        targets = (
            INLINE_LINK.findall(text)
            + IMAGE_LINK.findall(text)
            + REF_DEFINITION.findall(text)
        )
        for target in targets:
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE):
                continue  # external (http, https, mailto…)
            file_part, _, anchor = target.partition("#")
            dest = (md.parent / unquote(file_part)).resolve() if file_part else md
            rel = md.relative_to(ROOT)
            if not dest.exists():
                errors.append(f"{rel}: missing target '{target}'")
                continue
            if anchor and dest.suffix == ".md":
                if unquote(anchor).lower() not in anchors_of(dest, cache):
                    errors.append(f"{rel}: missing anchor '{target}'")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    print(f"checked {len(markdown_files())} Markdown files, {len(errors)} broken link(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(check())
