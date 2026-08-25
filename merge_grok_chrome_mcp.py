#!/usr/bin/env python3
"""Merge or strip [mcp_servers.chrome-devtools] in a Grok config.toml."""
from __future__ import annotations

import argparse
import re
import sys

PACKAGE_VERSION = "1.8.0"
MAX_OUTPUT_BYTES = "262144"

CHROME_BLOCK = f"""[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@{PACKAGE_VERSION}",
    "--autoConnect",
    "--no-category-performance",
    "--no-performance-crux",
    "--no-usage-statistics",
    "--screenshot-format=jpeg",
    "--screenshot-quality=60",
    "--screenshot-max-width=1280",
    "--screenshot-max-height=768",
    "--allow-unrestricted-paths",
]
startup_timeout_sec = 45
tool_timeout_sec = 45
tool_timeouts = {{ take_screenshot = 30, wait_for = 25 }}
enabled = true

[mcp_servers.chrome-devtools.env]
CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1"
CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1"
"""


def strip_chrome(src: str) -> str:
    return re.sub(
        r"\n?\[mcp_servers\.chrome-devtools(?:\.[^\]]+)?\][\s\S]*?(?=\n\[|\Z)",
        "\n",
        src,
    )


def upsert_mcp_max(src: str, value: str) -> str:
    m = re.search(r"(?m)^\[mcp\][ \t]*\n", src)
    if not m:
        return f"[mcp]\nmax_output_bytes = {value}\n\n" + src.lstrip()
    start = m.end()
    n = re.search(r"(?m)^\[", src[start:])
    end = start + n.start() if n else len(src)
    head, section, tail = src[: m.start()], src[m.start() : end], src[end:]
    if re.search(r"(?m)^max_output_bytes\s*=", section):
        section = re.sub(
            r"(?m)^max_output_bytes\s*=\s*\S+",
            f"max_output_bytes = {value}",
            section,
            count=1,
        )
    else:
        section = re.sub(
            r"(?m)^(\[mcp\][ \t]*\n)",
            rf"\1max_output_bytes = {value}\n",
            section,
            count=1,
        )
    return head + section.rstrip() + "\n\n" + tail.lstrip()


def collapse_blank(src: str) -> str:
    text = re.sub(r"\n{3,}", "\n\n", src)
    if text and not text.endswith("\n"):
        text += "\n"
    return text


def merge(src: str, *, uninstall: bool = False, max_bytes: str = MAX_OUTPUT_BYTES) -> str:
    text = strip_chrome(src)
    if uninstall:
        return collapse_blank(text.rstrip() + "\n")
    text = upsert_mcp_max(text, max_bytes)
    text = text.rstrip() + "\n\n" + CHROME_BLOCK.strip() + "\n"
    return collapse_blank(text)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("path", nargs="?", help="config.toml path; stdin if omitted")
    p.add_argument("--uninstall", action="store_true")
    p.add_argument("--max-output-bytes", default=MAX_OUTPUT_BYTES)
    p.add_argument("--print-block", action="store_true", help="print chrome TOML block and exit")
    args = p.parse_args(argv)
    if args.print_block:
        sys.stdout.write(CHROME_BLOCK if CHROME_BLOCK.endswith("\n") else CHROME_BLOCK + "\n")
        return 0
    if args.path:
        with open(args.path, encoding="utf-8") as f:
            src = f.read()
    else:
        src = sys.stdin.read()
    sys.stdout.write(merge(src, uninstall=args.uninstall, max_bytes=args.max_output_bytes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
