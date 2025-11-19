declare -A options
options[hypr]="Hyprland configuration"
options[bash]="Bash configuration"
options[astal]="Astal widgets configuration"
options[nvim]="Neovim configuration"
options[fuzzel]="Fuzzel launcher configuration"
options[foot]="Foot terminal configuration"
options[uwsm]="UWSM environment configuration"
options[starship]="Starship prompt configuration"
options[fastfetch]="Fastfetch configuration"
options[matugen]="Matugen theme configuration"
options[sunsetr]="Sunsetr display configuration"
options[systemd]="Systemd user units configuration"
options[help]="List of available options"

config() {
    case "$1" in
        hypr) cd "$XDG_CONFIG_HOME/hypr" && nvim ;;
        bash) cd "$XDG_CONFIG_HOME/bash" && nvim ;;
        astal) cd "$XDG_CONFIG_HOME/astal-widgets" && nvim ;;
        nvim) cd "$XDG_CONFIG_HOME/nvim" && nvim ;;
        fuzzel) cd "$XDG_CONFIG_HOME/fuzzel" && nvim fuzzel.ini ;;
        foot) cd "$XDG_CONFIG_HOME/foot" && nvim foot.ini ;;
        uwsm) cd "$XDG_CONFIG_HOME/uwsm" && nvim env ;;
        starship) cd "$XDG_CONFIG_HOME" && nvim starship.toml ;;
        fastfetch) cd "$XDG_CONFIG_HOME/fastfetch" && nvim config.jsonc ;;
        matugen) cd "$XDG_CONFIG_HOME/matugen" && nvim config.toml ;;
        sunsetr) cd "$XDG_CONFIG_HOME/sunsetr" && nvim sunsetr.toml ;;
        systemd) cd "$XDG_CONFIG_HOME/systemd/user" && nvim ;;
        help)

            echo -e "Config is a utility function that provides quick access to configuration files.\n"

            echo -e "Usage:\n\tconfig [option]\n"

            echo -e "The available option are:\n"

            for key in "${!options[@]}"; do
                printf "\t%-12s %s\n" "$key" "${options[$key]}"
            done

            ;;
        *)
            echo "[ERROR] option not implemented"
            config help
            ;;
    esac
}

_config_completions() {
    local cur opts

    # accept only one word for autocomplete
    if [[ $COMP_CWORD -ne 1 ]]; then
        COMPREPLY=()
        return
    fi

    # current input (as word, not whole input)
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="${!options[@]}"
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}

complete -F _config_completions config
