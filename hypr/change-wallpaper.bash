#!/bin/bash

hyprpaper_conf="$HYPR_CONFIG_DIR/hyprpaper.conf"

if [ -z "$1" ]; then
    echo "a wallpaper path is required"
    exit 1
fi

echo "setting wallpaper from image at '$1'"

# Run hyprctl hyprpaper reload and capture the first line of output
change_confirmation=$(hyprctl hyprpaper reload , "$1" | head -n 1)

if [ "$change_confirmation" = "ok" ]; then
    echo "wallpaper set!"
else
    echo "wallpaper set FAILED"
    echo "$change_confirmation"
    exit 1
fi

echo "saving wallpaper in $hyprpaper_conf"

# Overwrite the hyprpaper.conf file
echo "# DO NOT EDIT, AUTO-EDITED BY change-wallpaper.bash" > "$hyprpaper_conf"

# Save the current wallpaper path to the config
echo "preload = $1" >> "$hyprpaper_conf"
echo "wallpaper =, $1" >> "$hyprpaper_conf"

echo "wallpaper saved!"
