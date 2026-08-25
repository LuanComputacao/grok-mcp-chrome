#!/usr/bin/env python3
"""Smoke tests for merge_grok_chrome_mcp.merge (no pytest required)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from merge_grok_chrome_mcp import CHROME_BLOCK, merge  # noqa: E402

FIXTURE = """[cli]
installer = "internal"

[mcp_servers.stitch]
command = "npx"
enabled = true

[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@latest",
    "--autoConnect",
]
startup_timeout_sec = 120
enabled = true

[mcp_servers.github]
url = "https://example.invalid/"
enabled = true
"""


def assert_true(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def main() -> int:
    out = merge(FIXTURE)
    assert_true("[mcp_servers.stitch]" in out, "preserves other servers")
    assert_true('url = "https://example.invalid/"' in out, "preserves github")
    assert_true("chrome-devtools-mcp@latest" not in out, "replaces @latest")
    assert_true("chrome-devtools-mcp@1.8.0" in out, "pins 1.8.0")
    assert_true("--autoConnect" in out, "keeps autoConnect")
    assert_true("--screenshot-format=jpeg" in out, "jpeg flag")
    assert_true("[mcp]" in out and "max_output_bytes = 262144" in out, "raises MCP cap")
    assert_true(out.count("[mcp_servers.chrome-devtools]") == 1, "single chrome table")
    assert_true("[mcp_servers.chrome-devtools.env]" in out, "env table")
    assert_true("STITCH_API_KEY" not in out, "does not invent secrets")

    again = merge(out)
    assert_true(again == out, "idempotent")

    gone = merge(out, uninstall=True)
    assert_true("[mcp_servers.chrome-devtools]" not in gone, "uninstall strips chrome")
    assert_true("[mcp_servers.stitch]" in gone, "uninstall keeps stitch")
    assert_true("max_output_bytes = 262144" in gone, "uninstall keeps [mcp] cap")

    empty = merge("")
    assert_true(empty.startswith("[mcp]"), "empty file gets [mcp] first")
    assert_true("chrome-devtools-mcp@1.8.0" in empty, "empty file gets chrome block")
    assert_true(CHROME_BLOCK.strip() in empty, "block matches canonical")

    mcp_first = merge("[mcp]\nmax_output_bytes = 20\n\n[ui]\ntheme = \"x\"\n")
    assert_true("max_output_bytes = 262144" in mcp_first, "updates existing cap")
    assert_true('theme = "x"' in mcp_first, "keeps other [mcp]? wait this is [ui]")
    assert_true("[ui]" in mcp_first, "keeps [ui]")

    assert_true(out.endswith("\n"), "merged output ends with newline")
    assert_true(gone.endswith("\n"), "uninstall output ends with newline")

    print("ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
