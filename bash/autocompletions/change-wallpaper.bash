_change_wallpaper_completions() {
    local cur opts

    # current input (as word, not whole input)
    cur="${COMP_WORDS[COMP_CWORD]}"

    # accept only one word for autocomplete
    if [[ $COMP_CWORD -eq 1 ]]; then
        opts="$(change-wallpaper _options)"
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return
    fi

    _filedir
}

complete -F _change_wallpaper_completions change-wallpaper
