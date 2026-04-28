declare -A options
options[hypr]="Hyprland configuration"
options[bash]="Bash configuration"
options[nvim]="Neovim configuration"
options[fuzzel]="Fuzzel launcher configuration"
options[foot]="Foot terminal configuration"
options[caelestia]="Caelestia shell configuration"
options[uwsm]="UWSM environment configuration"
options[starship]="Starship prompt configuration"
options[fastfetch]="Fastfetch configuration"
options[sunsetr]="Sunsetr display configuration"
options[systemd]="Systemd user units configuration"
options[help]="List of available options"

config() {
    case "$1" in
        hypr) cd "$XDG_CONFIG_HOME/hypr" && nvim ;;
        bash) cd "$XDG_CONFIG_HOME/bash" && nvim ;;
        nvim) cd "$XDG_CONFIG_HOME/nvim" && nvim ;;
        fuzzel) cd "$XDG_CONFIG_HOME/fuzzel" && nvim fuzzel.ini ;;
        foot) cd "$XDG_CONFIG_HOME/foot" && nvim foot.ini ;;
        uwsm) cd "$XDG_CONFIG_HOME/uwsm" && nvim env ;;
        starship) cd "$XDG_CONFIG_HOME" && nvim starship.toml ;;
        fastfetch) cd "$XDG_CONFIG_HOME/fastfetch" && nvim config.jsonc ;;
        sunsetr) cd "$XDG_CONFIG_HOME/sunsetr" && nvim sunsetr.toml ;;
        systemd) cd "$XDG_CONFIG_HOME/systemd/user" && nvim ;;
        caelestia) cd "$XDG_CONFIG_HOME/caelestia" && nvim shell.json;;
        help)

            echo -e "Config is a utility function that provides quick access to configuration files.\n"

            echo -e "Usage:\n\t${FG_CYAN}config [option]${FMT_RESET}\n"

            echo -e "The availables options are:\n"

            for key in "${!options[@]}"; do
                printf "\t${FG_CYAN}%-12s${FMT_RESET} %s\n" "$key" "${options[$key]}"
            done

            ;;
        _options)
            echo "${!options[@]}"
            return 0
            ;;
        *)
            echo -e "[${FG_RED}ERROR${FMT_RESET}] option not implemented."
            config help
            ;;
    esac
}
