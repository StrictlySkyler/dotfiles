# dotfiles

Skyler Forge's configuration for Linux workstations
(Pop!_OS / Ubuntu-based, bash + oh-my-bash).

## Install

```bash
git clone git@github.com:StrictlySkyler/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
./install.sh
```

The script symlinks each file into `$HOME`.  Existing files are
backed up as `*.bak`.

## Secrets

`.exports` is gitignored.  Copy `.exports.example` to `~/.exports`
and fill in values on each machine.  The `.vimrc` API key slot is
commented out — set it via environment or a local override.

## What's included

| Path | Purpose |
|------|---------|
| `.bashrc` | oh-my-bash, completions, PATH, nvm/fvm/bun |
| `.bash_profile` | login shell bootstrap |
| `.profile` | system profile (Debian default + ~/bin) |
| `.aliases` | shortcuts: sudo, vim, AI service control |
| `.exports.example` | template for secret env vars |
| `.vimrc` | vim-plug, NERDTree, solarized, 2-space tabs |
| `.gitconfig` | user identity, kdiff3 diff/merge |
| `.config/ghostty/config` | Ghostty terminal theme + opacity |
| `.cursor/rules/` | Cursor IDE agent rules |
| `.honcho/config.json` | Honcho AI memory service config |
| `CLAUDE.md` | Claude Code project guidance |
