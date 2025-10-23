export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

eval "$(starship init bash)"

for file in $BASH_CONFIG_DIR/functions/*.bash; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

[ -f "$BASH_CONFIG_DIR/aliases.bash" ] && source "$BASH_CONFIG_DIR/aliases.bash"

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
