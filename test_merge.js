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
assertTrue(out.includes("enabled = true"), "keeps stitch enabled");
assertTrue(out.includes('url = "https://example.invalid/"'), "preserves github");
assertTrue(!out.includes("chrome-devtools-mcp@latest"), "replaces @latest");
assertTrue(out.includes("chrome-devtools-mcp@1.8.0"), "pins 1.8.0");
assertTrue(out.includes("--autoConnect"), "keeps autoConnect");
assertTrue(out.includes("--page-id-routing"), "explicit pageId routing");
assertTrue(out.includes("--redact-network-headers"), "redacts network headers");
assertTrue(!out.includes("--allow-unrestricted-paths"), "no unrestricted paths");
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
assertTrue((mcpFirst.match(/^\[mcp\]/gm) || []).length === 1, "no duplicate [mcp]");

assertTrue(out.endsWith("\n"), "merged output ends with newline");
assertTrue(gone.endsWith("\n"), "uninstall output ends with newline");

const comment = merge(`[mcp_servers.stitch]
command = "npx" # see [mcp_servers.chrome-devtools]
enabled = true
`);
assertTrue(comment.includes("enabled = true"), "comment with table name does not eat stitch");
assertTrue(comment.includes("# see [mcp_servers.chrome-devtools]"), "preserves inline comment");

const quoted = merge(`[mcp_servers.stitch]
args = [ "-y", "[mcp_servers.chrome-devtools]" ]
enabled = true
`);
assertTrue(quoted.includes('"[mcp_servers.chrome-devtools]"'), "quoted table name is not a header");
assertTrue(quoted.includes("enabled = true"), "quoted name does not eat following keys");

const crlf = merge("[mcp]\r\nmax_output_bytes = 20\r\n\r\n[ui]\r\ntheme = \"x\"\r\n");
assertTrue((crlf.match(/^\[mcp\]/gm) || []).length === 1, "CRLF does not duplicate [mcp]");
assertTrue(crlf.includes('theme = "x"'), "CRLF keeps [ui]");

const bom = merge("\uFEFF[mcp]\nmax_output_bytes = 20\n\n[ui]\ntheme = \"x\"\n");
assertTrue((bom.match(/^\[mcp\]/gm) || []).length === 1, "BOM does not duplicate [mcp]");

console.log("ok");
