_config_completions() {
    local cur opts

    # accept only one word for autocomplete
    if [[ $COMP_CWORD -ne 1 ]]; then
        COMPREPLY=()
        return
    fi

    # current input (as word, not whole input)
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="$(config _options)"
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}

complete -F _config_completions config
