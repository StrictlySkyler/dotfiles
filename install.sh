#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files/dirs that map directly to $HOME
TARGETS=(
  .bashrc
  .bash_profile
  .profile
  .aliases
  .vimrc
  .gitconfig
  .cursor/rules/honcho-memory.mdc
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

echo ""
echo "Done.  Review any .bak files and remove once verified."
