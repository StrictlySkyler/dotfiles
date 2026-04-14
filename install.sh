#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Symlink dotfiles into $HOME ──────────────────────────────────

TARGETS=(
  .bashrc
  .bash_profile
  .profile
  .aliases
  .vimrc
  .gitconfig
  .local/bin/honcho-prewarm-cursor.sh
  .local/bin/agent-wrapper
  .cursor/rules/honcho-memory.mdc
  .cursor/settings.json
  .honcho/config.json
  .honcho/mcp/server.mjs
  .honcho/mcp/package.json
)

for target in "${TARGETS[@]}"; do
  src="$DOTFILES_DIR/$target"
  dest="$HOME/$target"

  if [[ ! -f "$src" ]]; then
    echo "SKIP  $target (not in dotfiles repo)"
    continue
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    existing="$(readlink -f "$dest")"
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
  echo "LINK  $target"
done

if [[ ! -f "$HOME/.exports" ]]; then
  cp "$DOTFILES_DIR/.exports.example" "$HOME/.exports"
  echo "COPY  .exports (from template — fill in secrets)"
fi

if [[ -f "$HOME/.honcho/mcp/package.json" ]]; then
  echo ""
  echo "Installing Honcho MCP bridge dependencies..."
  (cd "$HOME/.honcho/mcp" && npm install --silent)
  echo "OK    .honcho/mcp/node_modules"
fi

if [[ -f "$DOTFILES_DIR/.local/bin/honcho-prewarm-cursor.sh" ]]; then
  chmod +x "$DOTFILES_DIR/.local/bin/honcho-prewarm-cursor.sh"
  if [[ -e "$HOME/.local/bin/honcho-prewarm-cursor.sh" ]]; then
    chmod +x "$HOME/.local/bin/honcho-prewarm-cursor.sh"
  fi
fi

# ── 1b. Cursor Agent alt-screen wrapper ─────────────────────────────
# The cursor-agent updater replaces ~/.local/bin/agent with a symlink.
# We replace it with our wrapper that adds alternate screen buffer support
# for ConEmu compatibility. Re-run install.sh after agent updates.

install_agent_wrapper() {
  local wrapper="$DOTFILES_DIR/.local/bin/agent-wrapper"
  local dest="$HOME/.local/bin/agent"

  if [[ ! -f "$wrapper" ]]; then
    echo "SKIP  agent-wrapper (not in dotfiles)"
    return
  fi

  if [[ ! -d "$HOME/.local/share/cursor-agent" ]]; then
    echo "SKIP  agent-wrapper (cursor-agent not installed)"
    return
  fi

  if [[ -L "$dest" ]]; then
    rm "$dest"
    echo "REPL  agent (was symlink → wrapper)"
  elif [[ -f "$dest" ]]; then
    if diff -q "$wrapper" "$dest" &>/dev/null; then
      echo "OK    agent-wrapper"
      return
    fi
    mv "$dest" "$dest.bak"
    echo "BAK   agent → $dest.bak"
  fi

  cp "$wrapper" "$dest"
  chmod +x "$dest"
  echo "INST  agent-wrapper → $dest"
}

install_agent_wrapper

# ── 2. cursor-honcho plugin (MCP server + hooks) ───────────────────

CURSOR_HONCHO_DIR="$HOME/.honcho/plugins/cursor-honcho"
PLUGIN_ROOT="$CURSOR_HONCHO_DIR/plugins/honcho"
CURSOR_HONCHO_REPO="https://github.com/plastic-labs/cursor-honcho.git"
CURSOR_HONCHO_PATCHER="$DOTFILES_DIR/scripts/patch_cursor_honcho.py"

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
  local bun_path
  bun_path="$(command -v bun)"
  mkdir -p "$HOME/.cursor"

  cat > "$dest" <<EOF
{
  "mcpServers": {
    "honcho": {
      "command": "$bun_path",
      "args": ["run", "$PLUGIN_ROOT/mcp-server.ts"],
      "env": {
        "HONCHO_API_KEY": "local",
        "HONCHO_ENDPOINT": "http://orphic-lens:8100",
        "HONCHO_PEER_NAME": "skyler",
        "HONCHO_TIMEOUT_MS": "300000"
      }
    }
  }
}
EOF
  echo "GEN   .cursor/mcp.json"
}

write_cursor_hooks_json() {
  local dest="$HOME/.cursor/hooks.json"
  local hooks_dir="$PLUGIN_ROOT/hooks"
  local bun_path
  local prewarm_cmd="$HOME/.local/bin/honcho-prewarm-cursor.sh"
  bun_path="$(command -v bun)"
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
  if getent hosts orphic-lens &>/dev/null; then
    echo "OK    orphic-lens resolves"
    return
  fi
  if grep -qsE '^[^#].*[[:space:]]orphic-lens' /etc/hosts; then
    echo "OK    orphic-lens in /etc/hosts"
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

  local endpoint peer_name
  endpoint=$(python3 -c "import json; print(json.load(open('$config')).get('endpoint',{}).get('baseUrl',''))" 2>/dev/null)
  peer_name=$(python3 -c "import json; print(json.load(open('$config')).get('peerName',''))" 2>/dev/null)

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
hosts = c.get('hosts', {})
sessions = list(c.get('sessions', {}).values())
peer = c.get('peerName', '')
for name, block in hosts.items():
    ws = block.get('workspace', name)
    ai = block.get('aiPeer', '')
    for s in sessions:
        print(f'{ws}\t{peer}\t{ai}\t{s}')
    if not sessions:
        print(f'{ws}\t{peer}\t{ai}\t')
" 2>/dev/null | while IFS=$'\t' read -r workspace peer ai_peer session; do
    [[ -z "$workspace" ]] && continue

    curl -sf --max-time 5 -X POST "$api/workspaces" \
      -H "Content-Type: application/json" \
      -d "{\"id\":\"$workspace\"}" >/dev/null 2>&1 || true

    [[ -n "$peer" ]] && \
      curl -sf --max-time 5 -X POST "$api/workspaces/$workspace/peers" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$peer\"}" >/dev/null 2>&1 || true

    [[ -n "$ai_peer" ]] && \
      curl -sf --max-time 5 -X POST "$api/workspaces/$workspace/peers" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$ai_peer\"}" >/dev/null 2>&1 || true

    [[ -n "$session" ]] && \
      curl -sf --max-time 5 -X POST "$api/workspaces/$workspace/sessions" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"$session\"}" >/dev/null 2>&1 || true

    echo "OK    honcho $workspace (peer: $peer, ai: $ai_peer, session: ${session:-none})"
  done
}

install_bun
install_cursor_honcho
patch_cursor_honcho
write_cursor_mcp_json
write_cursor_hooks_json
ensure_orphic_lens_dns
bootstrap_honcho_server

echo ""
echo "Done.  Review any .bak files and remove once verified."
echo "Restart Cursor to pick up MCP + hooks."
