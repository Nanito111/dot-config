#!/bin/bash

# load styles for printing
source "$BASH_CONFIG_DIR/style.bash"

declare -A options
options[wallpaper]="Change desktop image."
options[lockscreen]="Change lockscreen image."
options[help]="List of available options and descriptions"

option="$1"
image_path="$2"

pre_process(){
    if [ -z "$image_path" ]; then
        echo -e "${FG_RED}an image path is required${FMT_RESET}"
        exit 1
    fi

    # check if image exist
    if [ ! -f "$image_path" ]; then
        echo -e "${FG_RED}image does not exist${FMT_RESET}"
        exit 1
    fi

    echo -e "setting $option from image at ${FMT_UNDERLINE}${FG_CYAN}$image_path${FMT_RESET}"
}

set_wallpaper(){
    hyprpaper_conf="$HYPR_CONFIG_DIR/hyprpaper.conf"

    # Run hyprctl hyprpaper reload and capture the first line of output
    hyprctl hyprpaper wallpaper ,"$image_path"
    change_confirmation=$(echo $?)

    if [[ $change_confirmation -eq 0 ]] then
        echo -e "${FG_GREEN}wallpaper setted!${FMT_RESET}"
    else
        echo -e "${FG_RED}wallpaper cannot be setted${FMT_RESET}"
        exit $change_confirmation
    fi

    echo -e "\nsaving wallpaper ${FMT_UNDERLINE}${FG_CYAN}${image_path}${FMT_RESET}"

    # create or overwrite symlink for lockscreen image
    ln -sf "$image_path" "$HYPR_CONFIG_DIR/wallpaper-desktop"

    echo -e "${FG_GREEN}wallpaper saved!${FMT_RESET}"

    # generating new system colors
    echo -e "\ngenerating colors"

    matugen -t scheme-content image --source-color-index 0 "$image_path" -v

    echo -e "${FG_GREEN}colors generated!${FMT_RESET}"
}

set_lockscreen(){

    # create or overwrite symlink for lockscreen image
    ln -sf "$image_path" "$HYPR_CONFIG_DIR/wallpaper-lockscreen"

    echo -e "${FG_GREEN}lockscreen setted!${FMT_RESET}"
}

case "$option" in
    wallpaper)
        pre_process
        set_wallpaper
        ;;
    lockscreen)
        pre_process
        set_lockscreen
        ;;
    help)
        echo -e "change-wallpaper is a utility for setting the wallpaper or lock screen from an image path.\n"

        echo -e "Usage:\n\t${FG_CYAN}change-wallpaper [option] [path]${FMT_RESET}\n"

        echo -e "The availables options are:\n"

        for key in "${!options[@]}"; do
            printf "\t${FG_CYAN}%-12s${FMT_RESET} %s\n" "$key" "${options[$key]}"
        done
        ;;
    _options)
        echo "${!options[@]}"
        exit 0
        ;;
    *)
        echo -e "[${FG_RED}ERROR${FMT_RESET}] option not implemented."
        "$0" help
        exit 2
        ;;
esac
