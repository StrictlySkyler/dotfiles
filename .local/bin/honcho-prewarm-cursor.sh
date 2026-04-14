#!/usr/bin/env bash
set -euo pipefail

BUN_BIN="${BUN_BIN:-$HOME/.bun/bin/bun}"
PLUGIN_ROOT="${HONCHO_CURSOR_PLUGIN_ROOT:-$HOME/.honcho/plugins/cursor-honcho/plugins/honcho}"
STAMP_DIR="$HOME/.honcho/prewarm"
TTL_SECONDS="${HONCHO_PREWARM_TTL_SECONDS:-900}"

if [[ ! -x "$BUN_BIN" ]]; then
  if command -v bun >/dev/null 2>&1; then
    BUN_BIN="$(command -v bun)"
  else
    exit 0
  fi
fi

if [[ ! -d "$PLUGIN_ROOT" || ! -f "$HOME/.honcho/config.json" ]]; then
  exit 0
fi

mkdir -p "$STAMP_DIR"

cwd="${CURSOR_PROJECT_DIR:-$(pwd)}"
key="$(printf '%s' "$cwd" | sha1sum | awk '{print $1}')"
stamp="$STAMP_DIR/$key.stamp"
now="$(date +%s)"

if [[ -f "$stamp" ]]; then
  mtime="$(stat -c %Y "$stamp" 2>/dev/null || echo 0)"
  if (( now - mtime < TTL_SECONDS )); then
    exit 0
  fi
fi

touch "$stamp"

HONCHO_WARMUP_CWD="$cwd" HONCHO_TIMEOUT_MS="${HONCHO_TIMEOUT_MS:-300000}" nohup "$BUN_BIN" --cwd "$PLUGIN_ROOT" -e '
import { Honcho } from "@honcho-ai/sdk";
import { loadConfig, getHonchoClientOptions, getSessionName } from "./src/config.ts";

const cwd = process.env.HONCHO_WARMUP_CWD;
const config = loadConfig();
if (!config || !cwd) process.exit(0);

const timeout = Number(process.env.HONCHO_TIMEOUT_MS || "300000");
const honcho = new Honcho({ ...getHonchoClientOptions(config), timeout });
const sessionName = getSessionName(cwd);

const run = async () => {
  const session = await honcho.session(sessionName);
  const peer = await honcho.peer(config.peerName);
  await peer.chat(
    "Summarize the user'\''s current working style in one short sentence.",
    { session, reasoningLevel: "minimal" }
  );
};

run().catch(() => process.exit(0));
' >/dev/null 2>&1 &

exit 0
