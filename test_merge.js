#!/usr/bin/env node
"use strict";

const { merge, CHROME_BLOCK } = require("./merge_grok_chrome_mcp.js");

const FIXTURE = `[cli]
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
`;

function assertTrue(cond, msg) {
  if (!cond) {
    console.error(`FAIL: ${msg}`);
    process.exit(1);
  }
}

const out = merge(FIXTURE);
assertTrue(out.includes("[mcp_servers.stitch]"), "preserves other servers");
assertTrue(out.includes('url = "https://example.invalid/"'), "preserves github");
assertTrue(!out.includes("chrome-devtools-mcp@latest"), "replaces @latest");
assertTrue(out.includes("chrome-devtools-mcp@1.8.0"), "pins 1.8.0");
assertTrue(out.includes("--autoConnect"), "keeps autoConnect");
assertTrue(out.includes("--screenshot-format=jpeg"), "jpeg flag");
assertTrue(out.includes("[mcp]") && out.includes("max_output_bytes = 262144"), "raises MCP cap");
assertTrue((out.match(/\[mcp_servers\.chrome-devtools\]/g) || []).length === 1, "single chrome table");
assertTrue(out.includes("[mcp_servers.chrome-devtools.env]"), "env table");
assertTrue(!out.includes("STITCH_API_KEY"), "does not invent secrets");

const again = merge(out);
assertTrue(again === out, "idempotent");

const gone = merge(out, { uninstall: true });
assertTrue(!gone.includes("[mcp_servers.chrome-devtools]"), "uninstall strips chrome");
assertTrue(gone.includes("[mcp_servers.stitch]"), "uninstall keeps stitch");
assertTrue(gone.includes("max_output_bytes = 262144"), "uninstall keeps [mcp] cap");

const empty = merge("");
assertTrue(empty.startsWith("[mcp]"), "empty file gets [mcp] first");
assertTrue(empty.includes("chrome-devtools-mcp@1.8.0"), "empty file gets chrome block");
assertTrue(empty.includes(CHROME_BLOCK.trim()), "block matches canonical");

const mcpFirst = merge('[mcp]\nmax_output_bytes = 20\n\n[ui]\ntheme = "x"\n');
assertTrue(mcpFirst.includes("max_output_bytes = 262144"), "updates existing cap");
assertTrue(mcpFirst.includes('theme = "x"'), "keeps [ui] value");
assertTrue(mcpFirst.includes("[ui]"), "keeps [ui]");

assertTrue(out.endsWith("\n"), "merged output ends with newline");
assertTrue(gone.endsWith("\n"), "uninstall output ends with newline");

console.log("ok");
