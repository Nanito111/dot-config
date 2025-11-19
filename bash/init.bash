#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"

# history stuff
HISTCONTROL=ignoredups:erasedups
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend

# binds
[ -f "$BASH_CONFIG_DIR/binds.bash" ] && source "$BASH_CONFIG_DIR/binds.bash"

# load functions
for file in $BASH_CONFIG_DIR/functions/*.bash; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

[ -f "$BASH_CONFIG_DIR/aliases.bash" ] && source "$BASH_CONFIG_DIR/aliases.bash"

[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
export FZF_CTRL_R_OPTS="--height 40% --reverse --tac --no-sort"

[ -f /opt/miniforge/etc/profile.d/conda.sh ] && source /opt/miniforge/etc/profile.d/conda.sh

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE='/opt/miniforge/bin/mamba';
export MAMBA_ROOT_PREFIX='/home/francisco/.conda';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<
