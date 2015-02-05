# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"
DEFAULT_USER="skyler"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

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

# Uncomment the following line to disable command auto-correction.
# DISABLE_CORRECTION="true"

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
plugins=(autojump git bower brew compleat git-extras git-hubflow jsontools macports npm nyan python ruby screen sudo tmux tmuxinator vagrant web-search wd colored-man colorize command-not-found copydir cp copyfile extract pj jump battery emoji-clock encode64 mosh safe-paste screen sprunge sfffe forklift osx terminalapp lol rand-quote history)
#plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

export PATH="/Users/skyler/.rvm/gems/ruby-2.0.0-p247/bin:/Users/skyler/.rvm/gems/ruby-2.0.0-p247@global/bin:/Users/skyler/.rvm/rubies/ruby-2.0.0-p247/bin:/Users/skyler/.rvm/bin:/Users/skyler/.rvm/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/X11/bin:/usr/texbin:/usr/local/sbin:/usr/local:/usr/bin:/usr/sbin:/opt/local/bin:/opt/local/sbin:/bin:/sbin:/usr/local/Cellar/imagemagick/6.7.7-6/bin:/usr/local/share/npm/bin:~/bin:/usr/X11/bin:/Users/skyler/pear/bin:/Users/skyler/bin"
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

test -r /sw/bin/init.sh && . /sw/bin/init.sh
export CDPATH=$CDPATH:".:~:/Files:~/nerdwallet:~/Desktop:~/repos"
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

[ -s "/Users/skyler/.scm_breeze/scm_breeze.sh" ] && source "/Users/skyler/.scm_breeze/scm_breeze.sh"

# Some safeguarding for 'rm':
unsetopt RM_STAR_SILENT

# Learn a language with each git commit!
export LANG=fr
git(){[[ "$@" = commit\ -m*  ]]&&normit en $LANG ${${@:$#}//./} -t;command hub $@}

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root line)

source ~/antigen.zsh

antigen bundle djui/alias-tips
antigen bundle tarrasch/zsh-colors
antigen bundle zsh-users/zsh-syntax-highlighting

antigen apply

source ~/.aliases
source ~/.exports
source ~/.git.scmbrc


# zsh-bd
. $HOME/.zsh/plugins/bd/bd.zsh

bindkey '^f' forward-word
bindkey '^b' backward-word
