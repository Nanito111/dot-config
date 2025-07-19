#!/bin/bash

zoom_factor=$1

# get current zoom from hyprctl with regex
current_zoom=$(hyprctl getoption cursor:zoom_factor | awk '/^float.*/ {print $2}')

# calculate new_zoom
new_zoom=$(echo "$zoom_factor * $current_zoom" | bc)

# get if new zoom is below limit
new_zoom_below_limit=$(echo "$new_zoom < 1" | bc)

# reset zoom to x1
if (( new_zoom_below_limit )); then
    hyprctl -q keyword cursor:zoom_factor 1
    exit
fi

# change zoom to new zoom
hyprctl -q keyword cursor:zoom_factor $new_zoom
