export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/local:/usr/bin:/usr/sbin:/opt/local/bin:/opt/local/sbin:/bin:/sbin:/usr/local/Cellar/imagemagick/6.7.7-6/bin:/usr/local/share/npm/bin:~/scripts:/usr/X11/bin:/Users/skyler/pear/bin
export CDPATH=".:~:/Files:~/nerdwallet:~/Desktop:~/github"

test -r /sw/bin/init.sh && . /sw/bin/init.sh

# For node.js
export NODE_PATH=/usr/local/lib/node

# Avoid duplicates in History
export HISTCONTROL=ignoredups:erasedups
# Append History entries
shopt -s histappend

# Source all the things!
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
  [ -r "$file" ] && source "$file"
done
unset file

shopt -s cdspell

for option in autocd globstar; do
  shopt -s "$option" 2> /dev/null
done

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2 | tr ' ' '\n')" scp sftp ssh

# Autocomplete Grunt commands
which grunt > /dev/null && eval "$(grunt --completion=bash)"

# If possible, add tab completion for many more commands
if [ -f /usr/local/Cellar/bash-completion/1.3/etc/bash_completion ]
then
  . /usr/local/Cellar/bash-completion/1.3/etc/bash_completion
elif [ -f /etc/bash_completion ]
then
  source /etc/bash_completion
else
  echo "No \"bash_completion\" package seems to be installed."
fi

# npm autocompletion
. <(npm completion)


# Credits to npm's. Awesome completion utility.
#
# Bower completion script, based on npm completion script.

###-begin-bower-completion-###
#
# Installation: bower completion >> ~/.bashrc  (or ~/.zshrc)
# Or, maybe: bower completion > /usr/local/etc/bash_completion.d/npm
#

COMP_WORDBREAKS=${COMP_WORDBREAKS/=/}
COMP_WORDBREAKS=${COMP_WORDBREAKS/@/}
export COMP_WORDBREAKS

if type complete &>/dev/null; then
  _bower_completion () {
    local si="$IFS"
    IFS=$'\n' COMPREPLY=($(COMP_CWORD="$COMP_CWORD" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           bower completion -- "${COMP_WORDS[@]}" \
                           2>/dev/null)) || return $?
    IFS="$si"
  }
  complete -F _bower_completion bower
elif type compdef &>/dev/null; then
  _bower_completion() {
    si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 bower completion -- "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }
  compdef _bower_completion bower
elif type compctl &>/dev/null; then
  _bower_completion () {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       bower completion -- "${words[@]}" \
                       2>/dev/null)) || return $?
    IFS="$si"
  }
  compctl -K _bower_completion bower
fi
###-end-bower-completion-###

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session     *as a function*

# tmux helper
complete -W "$(teamocil --list)" teamocil
