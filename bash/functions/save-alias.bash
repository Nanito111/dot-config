save-alias() {
    local alias_file="$BASH_CONFIG_DIR/aliases.bash"
    local name="$1"
    shift
    local command="$*"

    # check if alias name is empty
    if [[ -z "$name" ]]; then
        echo "alias name can't be empty"
        return 1
    fi

    # check if alias command is empty
    if [[ -z "$command" ]]; then
        echo "alias command can't be empty"
        return 1
    fi

    echo "alias $name='$command'" >> "$alias_file"

    echo "alias '$name' saved to $alias_file"

    source $alias_file
}

# usage
# save-alias ll='ls -l'
