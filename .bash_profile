# .bash_profile -*- mode: sh -*-

# Load login settings and environment variables
if [[ -f ~/.profile ]]; then
source ~/.profile
fi

# Load interactive settings
if [[ -f ~/.bashrc ]]; then
source ~/.bashrc
fi

if [[ -f "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi
export PATH=/home/skyler/.meteor:$PATH


# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
