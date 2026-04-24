#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect platform: macos | linux | wsl
platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      [[ -f /proc/version ]] && grep -qi microsoft /proc/version && echo wsl || echo linux ;;
    *) echo linux ;;
  esac
}
PLATFORM="$(platform)"

# Portable readlink -f (macOS lacks it)
realpath_() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
  else
    readlink -f "$1"
  fi
}

# ── 1. Symlink dotfiles into $HOME ──────────────────────────────────

# Common targets for all platforms
TARGETS=(
  .aliases
  .vimrc
  .gitconfig
  .local/bin/agent
  .local/bin/cursor-agent
  .local/bin/honcho-prewarm-cursor.sh
  .cursor/rules/honcho-memory.mdc
  .cursor/settings.json
  .honcho/config.json
  .honcho/mcp/server.mjs
  .honcho/mcp/package.json
)

# Shell init files only on Linux/WSL (macOS uses zsh; manage separately)
if [[ "$PLATFORM" != macos ]]; then
  TARGETS+=(
    .bashrc
    .bash_profile
    .profile
  )
fi

for target in "${TARGETS[@]}"; do
  src="$DOTFILES_DIR/$target"
  dest="$HOME/$target"

  if [[ ! -f "$src" ]]; then
    echo "SKIP  $target (not in dotfiles repo)"
    continue
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    existing="$(realpath_ "$dest" 2>/dev/null || true)"
    if [[ "$existing" == "$src" ]]; then
      echo "OK    $target"
      continue
    fi
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.bak"
    echo "BAK   $target → $dest.bak"
  fi

  ln -s "$src" "$dest"
  # Ensure scripts in .local/bin are executable via the source file
  case "$target" in .local/bin/*) chmod +x "$src" ;; esac
  echo "LINK  $target"
done

if [[ ! -f "$HOME/.exports" ]] && [[ -f "$DOTFILES_DIR/.exports.example" ]]; then
  cp "$DOTFILES_DIR/.exports.example" "$HOME/.exports"
  echo "COPY  .exports (from template — fill in secrets)"
fi

if [[ -f "$HOME/.honcho/mcp/package.json" ]]; then
  echo ""
  echo "Installing Honcho MCP bridge dependencies..."
  (cd "$HOME/.honcho/mcp" && npm install --silent)
  echo "OK    .honcho/mcp/node_modules"
fi

# ── 2. cursor-honcho plugin (MCP server + hooks) ───────────────────

CURSOR_HONCHO_DIR="$HOME/.honcho/plugins/cursor-honcho"
PLUGIN_ROOT="$CURSOR_HONCHO_DIR/plugins/honcho"
CURSOR_HONCHO_REPO="https://github.com/plastic-labs/cursor-honcho.git"
CURSOR_HONCHO_PATCHER="$DOTFILES_DIR/scripts/patch_cursor_honcho.py"
HERMES_PATCHER="$DOTFILES_DIR/scripts/patch_hermes_config.py"

install_bun() {
  if command -v bun &>/dev/null; then
    echo "OK    bun $(bun --version)"
    return
  fi
  echo "INST  bun"
  curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
}

install_cursor_honcho() {
  if [[ -d "$CURSOR_HONCHO_DIR/.git" ]]; then
    echo "OK    cursor-honcho (updating)"
    git -C "$CURSOR_HONCHO_DIR" pull --quiet 2>/dev/null || true
  else
    echo "INST  cursor-honcho → $CURSOR_HONCHO_DIR"
    mkdir -p "$(dirname "$CURSOR_HONCHO_DIR")"
    git clone --quiet --depth 1 "$CURSOR_HONCHO_REPO" "$CURSOR_HONCHO_DIR"
  fi
  (cd "$PLUGIN_ROOT" && bun install --silent 2>/dev/null)
  echo "OK    cursor-honcho deps"
}

patch_cursor_honcho() {
  if [[ ! -f "$CURSOR_HONCHO_PATCHER" ]]; then
    echo "SKIP  cursor-honcho patches (missing patcher)"
    return
  fi
  python3 "$CURSOR_HONCHO_PATCHER" "$PLUGIN_ROOT"
  echo "OK    cursor-honcho local fixes"
}

write_cursor_mcp_json() {
  local dest="$HOME/.cursor/mcp.json"
  local server="$HOME/.honcho/mcp/server.mjs"
  mkdir -p "$HOME/.cursor"

  # Merge: preserve any existing servers, then upsert honcho entry.
  # Base URL is resolved at runtime from config.json (kept current by .bashrc).
  python3 - "$dest" "$server" <<'PY'
import json, sys
from pathlib import Path

dest, server = Path(sys.argv[1]), sys.argv[2]
data = json.loads(dest.read_text()) if dest.exists() else {}
data.setdefault("mcpServers", {})["honcho"] = {
    "command": "node",
    # server.mjs is symlinked from the dotfiles repo, while node_modules is
    # installed under ~/.honcho/mcp. Keep Node's main-module lookup at the
    # symlink path so dependency resolution uses the installed dependencies.
    "args": ["--preserve-symlinks-main", server],
    "env": {
        "HONCHO_API_KEY": "local",
        "HONCHO_HUMAN_PEER": "skyler",
    },
}
dest.write_text(json.dumps(data, indent=2) + "\n")
PY
  echo "GEN   .cursor/mcp.json"
}

smoke_test_honcho_mcp() {
  local dest="$HOME/.cursor/mcp.json"
  python3 - "$dest" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

dest = Path(sys.argv[1])
data = json.loads(dest.read_text())
server = data.get("mcpServers", {}).get("honcho")
if not server:
    print("WARN  Honcho MCP smoke test skipped (no honcho server in mcp.json)")
    raise SystemExit(0)

cmd = [server["command"], *server.get("args", [])]
env = os.environ.copy()
env.update(server.get("env", {}))
payload = "\n".join([
    json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "dotfiles-install", "version": "0"},
        },
    }),
    json.dumps({
        "jsonrpc": "2.0",
        "method": "notifications/initialized",
        "params": {},
    }),
    json.dumps({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {},
    }),
    "",
])

try:
    result = subprocess.run(
        cmd,
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        timeout=10,
        check=False,
    )
except FileNotFoundError as exc:
    print(f"FAIL  Honcho MCP smoke test could not start: {exc}", file=sys.stderr)
    raise SystemExit(1)
except subprocess.TimeoutExpired:
    print("FAIL  Honcho MCP smoke test timed out", file=sys.stderr)
    raise SystemExit(1)

if result.returncode != 0 or '"tools"' not in result.stdout:
    print("FAIL  Honcho MCP smoke test failed", file=sys.stderr)
    if result.stderr:
        print(result.stderr.strip(), file=sys.stderr)
    raise SystemExit(1)

print("OK    Honcho MCP bridge smoke test")
PY
}

write_cursor_hooks_json() {
  local dest="$HOME/.cursor/hooks.json"
  local hooks_dir="$PLUGIN_ROOT/hooks"
  local bun_path prewarm_cmd
  bun_path="$(command -v bun)"
  prewarm_cmd="$HOME/.local/bin/honcho-prewarm-cursor.sh"
  mkdir -p "$HOME/.cursor"

  cat > "$dest" <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "$prewarm_cmd" },
      { "command": "$bun_path run $hooks_dir/session-start.ts" }
    ],
    "sessionEnd": [
      { "command": "$bun_path run $hooks_dir/session-end.ts" }
    ],
    "beforeSubmitPrompt": [
      { "command": "$bun_path run $hooks_dir/before-submit-prompt.ts" }
    ],
    "postToolUse": [
      {
        "command": "$bun_path run $hooks_dir/post-tool-use.ts",
        "matcher": "Write|Edit|Shell|Task|MCP"
      }
    ],
    "preCompact": [
      { "command": "$bun_path run $hooks_dir/pre-compact.ts" }
    ],
    "stop": [
      { "command": "$bun_path run $hooks_dir/stop.ts" }
    ],
    "subagentStop": [
      { "command": "$bun_path run $hooks_dir/subagent-stop.ts" }
    ],
    "afterAgentThought": [
      { "command": "$bun_path run $hooks_dir/after-agent-thought.ts" }
    ],
    "afterAgentResponse": [
      { "command": "$bun_path run $hooks_dir/after-agent-response.ts" }
    ]
  }
}
EOF
  echo "GEN   .cursor/hooks.json"
}

ensure_orphic_lens_dns() {
  # Check /etc/hosts first (works even when the tunnel/server is down)
  if grep -qsE '^[^#].*[[:space:]]orphic-lens' /etc/hosts; then
    echo "OK    orphic-lens in /etc/hosts"
    return
  fi
  # Fall back to live lookup (handles system DNS, mDNS, etc.)
  if command -v getent >/dev/null 2>&1 && getent hosts orphic-lens &>/dev/null; then
    echo "OK    orphic-lens resolves"
    return
  fi
  if command -v dscacheutil >/dev/null 2>&1 && dscacheutil -q host -a name orphic-lens 2>/dev/null | grep -q ip_address; then
    echo "OK    orphic-lens resolves"
    return
  fi

  echo "FIX   orphic-lens not resolvable — adding to /etc/hosts"
  echo '192.168.50.227 orphic-lens' | sudo tee -a /etc/hosts >/dev/null
  echo "OK    orphic-lens → 192.168.50.227"
}

bootstrap_honcho_server() {
  local config="$HOME/.honcho/config.json"
  if [[ ! -f "$config" ]]; then
    echo "SKIP  Honcho bootstrap (no config file)"
    return
  fi

  local endpoint
  endpoint=$(python3 -c "import json; print(json.load(open('$config')).get('endpoint',{}).get('baseUrl',''))" 2>/dev/null)

  if [[ -z "$endpoint" ]]; then
    echo "SKIP  Honcho bootstrap (no endpoint in config)"
    return
  fi

  if ! curl -sf --max-time 5 "$endpoint/docs" >/dev/null 2>&1; then
    echo "WARN  Honcho server at $endpoint not reachable — skipping bootstrap"
    echo "      Run ./install.sh again once the server is up."
    return
  fi

  local api="$endpoint/v3"

  python3 -c "
import json, sys
c = json.load(open('$config'))
sessions = list(c.get('sessions', {}).values())
peer = c.get('peerName', '')
for name, block in c.get('hosts', {}).items():
    ws = block.get('workspace', name)
    ai = block.get('aiPeer', '')
    for s in sessions or ['']:
        print(f'{ws}\t{peer}\t{ai}\t{s}')
" 2>/dev/null | while IFS=$'\t' read -r workspace peer ai_peer session; do
    [[ -z "$workspace" ]] && continue
    local api_base="$api/workspaces"
    curl -sf --max-time 5 -X POST "$api_base" \
      -H "Content-Type: application/json" \
      -d "{\"id\":\"$workspace\"}" >/dev/null 2>&1 || true
    [[ -n "$peer" ]] && \
      curl -sf --max-time 5 -X POST "$api_base/$workspace/peers" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$peer\"}" >/dev/null 2>&1 || true
    [[ -n "$ai_peer" ]] && \
      curl -sf --max-time 5 -X POST "$api_base/$workspace/peers" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$ai_peer\"}" >/dev/null 2>&1 || true
    [[ -n "$session" ]] && \
      curl -sf --max-time 5 -X POST "$api_base/$workspace/sessions" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$session\"}" >/dev/null 2>&1 || true
    echo "OK    honcho $workspace (peer: $peer, ai: $ai_peer, session: ${session:-none})"
  done
}

disable_cursor_git_attribution() {
  local script="$DOTFILES_DIR/scripts/disable_cursor_git_attribution.py"
  if [[ -f "$script" ]]; then
    if ! python3 "$script"; then
      echo "WARN  cursor attribution script failed" >&2
    fi
  else
    echo "SKIP  cursor attribution (missing script)"
  fi
}

patch_hermes_config() {
  if [[ -f "$HERMES_PATCHER" ]]; then
    python3 "$HERMES_PATCHER" "$HOME/.hermes"
  else
    echo "SKIP  Hermes config patch (missing patcher)"
  fi
}

install_bun
install_cursor_honcho
patch_cursor_honcho
write_cursor_mcp_json
smoke_test_honcho_mcp
write_cursor_hooks_json
disable_cursor_git_attribution
patch_hermes_config
ensure_orphic_lens_dns
bootstrap_honcho_server

# ── 3. ConEmu terminal settings (WSL only) ─────────────────────────
if [[ "$PLATFORM" == wsl ]] && [[ -f "$DOTFILES_DIR/scripts/configure_conemu.sh" ]]; then
  bash "$DOTFILES_DIR/scripts/configure_conemu.sh"
fi

echo ""
echo "Done.  Review any .bak files and remove once verified."
echo "Restart Cursor to pick up MCP + hooks."
