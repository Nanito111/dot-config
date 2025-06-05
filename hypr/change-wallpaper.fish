#!/bin/fish

set -l hyprpaper_conf "$HYPR_CONFIG_DIR/hyprpaper.conf"

if test -z "$argv"
  echo "a wallpaper path is required"
  return 1
end

echo "setting wallpaper from image at '$argv'"
hyprctl hyprpaper reload , "$argv" | read -l change_confirmation

if test "$change_confirmation" = "ok"
  echo "wallpaper set!"
  set -e $change_confirmation

else
  echo "wallpaper set FAILED"
  echo "$change_confirmation"

  set -e $change_confirmation

  return 1
end

echo "saving wallpaper in $hyprpaper_conf"

# this line will override hyprpaper.conf
echo "# DO NOT EDIT, AUTO-EDITED BY change-wallpaper.fish" &> $hyprpaper_conf

# this will save the current wallpaper, so it will not disappear-
# with system shutdown
echo "preload = $argv" >> $hyprpaper_conf
echo "wallpaper =, $argv" >> $hyprpaper_conf

set -e hyprpaper_conf

echo "wallpaper saved!"
