#!/bin/fish

if test -z "$argv"
  echo "A wallpaper path is required"
  return 1
end

echo "Setting wallpaper from image at '$argv'"
hyprctl hyprpaper reload , "$argv"

echo "Saving wallpaper in hyprpaper.conf"

echo "#DO NOT EDIT, AUTO-EDITED BY change-wallpaper.fish" &> $HOME/.config/hypr/hyprpaper.conf
echo "preload = '$argv'" >> $HOME/.config/hypr/hyprpaper.conf
echo "wallpaper = , '$argv'" >> $HOME/.config/hypr/hyprpaper.conf

echo "OK"
