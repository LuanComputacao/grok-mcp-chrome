#!/usr/bin/env node
"use strict";
/** Merge or strip [mcp_servers.chrome-devtools] in a Grok config.toml. */

const fs = require("fs");

const PACKAGE_VERSION = "1.8.0";
const MAX_OUTPUT_BYTES = "262144";

const CHROME_BLOCK = `[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@${PACKAGE_VERSION}",
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
tool_timeouts = { take_screenshot = 30, wait_for = 25 }
enabled = true

[mcp_servers.chrome-devtools.env]
CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1"
CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1"
`;

function stripChrome(src) {
  return src.replace(
    /\n?\[mcp_servers\.chrome-devtools(?:\.[^\]]+)?\][\s\S]*?(?=\n\[|$)/g,
    "\n",
  );
}

function upsertMcpMax(src, value) {
  const m = src.match(/^\[mcp\][ \t]*\n/m);
  if (!m) {
    return `[mcp]\nmax_output_bytes = ${value}\n\n` + src.replace(/^\s+/, "");
  }
  const start = m.index + m[0].length;
  const rest = src.slice(start);
  const n = rest.match(/^\[/m);
  const end = n ? start + n.index : src.length;
  const head = src.slice(0, m.index);
  let section = src.slice(m.index, end);
  const tail = src.slice(end);
  if (/^max_output_bytes\s*=/m.test(section)) {
    section = section.replace(
      /^max_output_bytes\s*=\s*\S+/m,
      `max_output_bytes = ${value}`,
    );
  } else {
    section = section.replace(
      /^(\[mcp\][ \t]*\n)/m,
      `$1max_output_bytes = ${value}\n`,
    );
  }
  return head + section.replace(/\s+$/, "") + "\n\n" + tail.replace(/^\s+/, "");
}

function collapseBlank(src) {
  let text = src.replace(/\n{3,}/g, "\n\n");
  if (text && !text.endsWith("\n")) text += "\n";
  return text;
}

function merge(src, { uninstall = false, maxBytes = MAX_OUTPUT_BYTES } = {}) {
  let text = stripChrome(src);
  if (uninstall) {
    return collapseBlank(text.replace(/\s+$/, "") + "\n");
  }
  text = upsertMcpMax(text, maxBytes);
  text = text.replace(/\s+$/, "") + "\n\n" + CHROME_BLOCK.trim() + "\n";
  return collapseBlank(text);
}

function parseArgs(argv) {
  const out = {
    uninstall: false,
    printBlock: false,
    maxBytes: MAX_OUTPUT_BYTES,
    path: null,
  };
  const rest = argv.slice(2);
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    if (a === "--uninstall") out.uninstall = true;
    else if (a === "--print-block") out.printBlock = true;
    else if (a === "--max-output-bytes") {
      out.maxBytes = rest[++i];
    } else if (a.startsWith("-")) {
      console.error(`Flag desconhecida: ${a}`);
      process.exit(2);
    } else if (!out.path) {
      out.path = a;
    }
  }
  return out;
}

function main() {
  const args = parseArgs(process.argv);
  if (args.printBlock) {
    process.stdout.write(CHROME_BLOCK.endsWith("\n") ? CHROME_BLOCK : CHROME_BLOCK + "\n");
    return;
  }
  const src = args.path
    ? fs.readFileSync(args.path, "utf8")
    : fs.readFileSync(0, "utf8");
  process.stdout.write(
    merge(src, { uninstall: args.uninstall, maxBytes: args.maxBytes }),
  );
}

module.exports = { merge, CHROME_BLOCK, PACKAGE_VERSION, MAX_OUTPUT_BYTES };

if (require.main === module) {
  main();
}
