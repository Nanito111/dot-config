#!/bin/bash

UNDERLINE_CYAN='\033[4;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET_COLOR='\033[0m'

hyprpaper_conf="$HYPR_CONFIG_DIR/hyprpaper.conf"

if [ -z "$1" ]; then
    echo -e "${RED}a wallpaper path is required${RESET_COLOR}"
    exit 1
fi

echo -e "setting wallpaper from image at ${UNDERLINE_CYAN}${1}${RESET_COLOR}"

# Run hyprctl hyprpaper reload and capture the first line of output
change_confirmation=$(hyprctl hyprpaper reload , "$1" | head -n 1)

if [ "$change_confirmation" = "ok" ]; then
    echo -e "${GREEN}wallpaper setted!${RESET_COLOR}"
else
    echo -e "${RED}wallpaper cannot be setted${RESET_COLOR}"
    echo "$change_confirmation"
    exit 1
fi

echo -e "\nsaving wallpaper in ${UNDERLINE_CYAN}${hyprpaper_conf}${RESET_COLOR}"

# Overwrite the hyprpaper.conf file
echo "# DO NOT EDIT, AUTO-EDITED BY change-wallpaper.bash" > "$hyprpaper_conf"
# Save the current wallpaper path to the config
echo "preload = $1" >> "$hyprpaper_conf"
echo "wallpaper =, $1" >> "$hyprpaper_conf"

echo -e "${GREEN}wallpaper saved!${RESET_COLOR}"

# generating new system colors
echo -e "\ngenerating colors"

matugen -t scheme-content image "$1" -v

echo -e "${GREEN}colors generated!${RESET_COLOR}"
