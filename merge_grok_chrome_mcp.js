#!/usr/bin/env node
"use strict";
/**
 * Merge or strip [mcp_servers.chrome-devtools] in a Grok config.toml.
 * Line-anchored table edits so comments/strings containing the name are left alone.
 */

const fs = require("fs");

const PACKAGE_VERSION = "1.8.0";
const MAX_OUTPUT_BYTES = "262144";

const CHROME_BLOCK = `[mcp_servers.chrome-devtools]
command = "npx"
args = [
    "-y",
    "chrome-devtools-mcp@${PACKAGE_VERSION}",
    "--autoConnect",
    "--page-id-routing",
    "--redact-network-headers",
    "--no-category-performance",
    "--no-performance-crux",
    "--no-usage-statistics",
    "--screenshot-format=jpeg",
    "--screenshot-quality=60",
    "--screenshot-max-width=1280",
    "--screenshot-max-height=768",
]
startup_timeout_sec = 45
tool_timeout_sec = 45
tool_timeouts = { take_screenshot = 30, wait_for = 25 }
enabled = true

[mcp_servers.chrome-devtools.env]
CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1"
CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1"
`;

const TABLE_CHROME = /^\[mcp_servers\.chrome-devtools(?:\.[^\]]+)?\][ \t]*$/;
const TABLE_ANY = /^\[/;
const TABLE_MCP = /^\[mcp\][ \t]*$/;

function normalize(src) {
  return String(src)
    .replace(/^\uFEFF/, "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n");
}

function stripChrome(src) {
  const lines = normalize(src).split("\n");
  const out = [];
  let skipping = false;
  for (const line of lines) {
    if (TABLE_CHROME.test(line)) {
      skipping = true;
      continue;
    }
    if (skipping) {
      if (TABLE_ANY.test(line) && !TABLE_CHROME.test(line)) {
        skipping = false;
        out.push(line);
      }
      continue;
    }
    out.push(line);
  }
  return out.join("\n");
}

function upsertMcpMax(src, value) {
  const lines = normalize(src).split("\n");
  let mcpStart = -1;
  let mcpEnd = lines.length;
  for (let i = 0; i < lines.length; i++) {
    if (TABLE_MCP.test(lines[i])) {
      mcpStart = i;
      for (let j = i + 1; j < lines.length; j++) {
        if (TABLE_ANY.test(lines[j])) {
          mcpEnd = j;
          break;
        }
      }
      break;
    }
  }
  if (mcpStart < 0) {
    const body = src.replace(/^\s+/, "");
    return `[mcp]\nmax_output_bytes = ${value}\n\n` + body;
  }
  const head = lines.slice(0, mcpStart);
  const section = lines.slice(mcpStart, mcpEnd);
  const tail = lines.slice(mcpEnd);
  let replaced = false;
  const next = section.map((line) => {
    if (/^max_output_bytes\s*=/.test(line)) {
      replaced = true;
      return `max_output_bytes = ${value}`;
    }
    return line;
  });
  if (!replaced) {
    next.splice(1, 0, `max_output_bytes = ${value}`);
  }
  return [...head, ...next, ...tail].join("\n");
}

function collapseBlank(src) {
  let text = normalize(src).replace(/\n{3,}/g, "\n\n");
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
      const v = rest[++i];
      if (!v) {
        console.error("--max-output-bytes exige um número");
        process.exit(2);
      }
      out.maxBytes = v;
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
