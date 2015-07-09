# Path to your oh-my-zsh installation.
export ZSH=/home/skyler/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"
DEFAULT_USER="skyler"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(autojump git bower brew compleat git-extras git-hubflow jsontools macports npm nyan python ruby screen sudo tmux web-search wd colored-man colorize command-not-found copydir cp copyfile extract pj jump battery encoded64 mosh safe-paste screen sprunge forklift history)
#plugins=(git)

# User configuration

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/home/skyler/bin:/home/skyler/bin/java/bin"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

unsetopt RM_STAR_SILENT

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root line)

source ~/antigen.zsh

antigen bundle djui/alias-tips
antigen bundle tarrasch/zsh-colors
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle rimraf/k

antigen apply

export NVM_DIR="/home/skyler/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

export PATH="/home/skyler/.linuxbrew/bin:$PATH" # For homebrew

source ~/.aliases
source ~/.exports
source ~/.git.scmbrc

bindkey '^f' forward-word
bindkey '^b' backward-word

[ -s "/home/skyler/.scm_breeze/scm_breeze.sh" ] && source "/home/skyler/.scm_breeze/scm_breeze.sh"

source ~/t-completion.zsh
source ~/repos/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/repos/git-hub/init

#Rebind HOME and END to do the decent thing:
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

# ctrl-left/right
bindkey "\e[1;5C" forward-word
bindkey "\e[1;5D" backward-word

# ctrl-backspace/delete
bindkey "\e^?" backward-kill-word
bindkey "\e[3;5~" kill-word
