remove-alias() {
    local alias_file="$BASH_CONFIG_DIR/aliases.bash"
    local alias_name="$1"

    if [[ -z "$alias_name" ]]; then
        echo "Usage: remove-alias alias_name"
        return 1
    fi

    if [[ ! -f "$alias_file" ]]; then
        echo "Alias file does not exist: $alias_file"
        return 1
    fi

    # Remove lines starting with "alias alias_name="
    # Make a backup first just in case
    cp "$alias_file" "$alias_file.bak"

    # Use sed to delete the alias line
    sed -i "/^alias $alias_name=/d" "$alias_file"

    # remove alias from current session
    if alias "$alias_name" &>/dev/null; then
        unalias "$alias_name"
        echo "alias '$alias_name' removed from session and file."
    else
        echo "alias '$alias_name' removed from file (not active on session)."
    fi
}
