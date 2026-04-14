# dotfiles

Skyler Forge's configuration for Linux workstations
(Pop!_OS / Ubuntu-based, bash + oh-my-bash).

## Install

```bash
git clone git@github.com:StrictlySkyler/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
./install.sh
```

The script:

1. Symlinks each dotfile into `$HOME` (existing files backed up as `*.bak`).
2. Installs **bun** if missing.
3. Clones/updates [cursor-honcho](https://github.com/plastic-labs/cursor-honcho)
   to `~/.honcho/plugins/cursor-honcho`, runs `bun install`, and applies
   local compatibility patches.
4. Generates `~/.cursor/mcp.json` and `~/.cursor/hooks.json` with
   absolute paths, a 5 minute MCP timeout, and a detached Honcho warmup
   hook for this machine.
5. Ensures `orphic-lens` resolves (adds `/etc/hosts` entry if needed;
   may prompt for `sudo`).
6. **Bootstraps the Honcho server** — creates workspaces, peers, and
   sessions for every host in `.honcho/config.json`. Idempotent and
   safe to re-run. Skips gracefully if the server is unreachable.

After running, restart Cursor.

## Secrets

`.exports` is gitignored.  Copy `.exports.example` to `~/.exports`
and fill in values on each machine.  The `.vimrc` API key slot is
commented out — set it via environment or a local override.

## What's included

| Path | Purpose |
|------|---------|
| `.bashrc` | oh-my-bash, completions, PATH, nvm/fvm/bun, Honcho env vars |
| `.bash_profile` | login shell bootstrap |
| `.profile` | system profile (Debian default + ~/bin) |
| `.aliases` | shortcuts: sudo, vim, AI service control |
| `.exports.example` | template for secret env vars |
| `.vimrc` | vim-plug, NERDTree, solarized, 2-space tabs |
| `.gitconfig` | user identity, kdiff3 diff/merge |
| `.cursor/rules/` | Cursor IDE agent rules |
| `.cursor/settings.json` | Cursor/agent settings (MCP timeout, etc.) |
| `.honcho/config.json` | Honcho memory config (self-hosted at orphic-lens) |
| `.local/bin/honcho-prewarm-cursor.sh` | Detached session-start warmup for Honcho dialectic chat |
| `scripts/patch_cursor_honcho.py` | Applies local fixes to the upstream cursor-honcho clone |

### Generated at install time (not in repo)

| Path | Purpose |
|------|---------|
| `~/.cursor/mcp.json` | Cursor MCP server config (absolute paths) |
| `~/.cursor/hooks.json` | Cursor lifecycle hooks (absolute paths) |
