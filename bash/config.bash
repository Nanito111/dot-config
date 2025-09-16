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
