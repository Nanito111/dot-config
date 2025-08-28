#!/bin/bash


LOCKFILE="/tmp/$(basename "$0").lock"

if [ -e "$LOCKFILE" ]; then
    echo "hyprshot already running. cancelling capture."
    exit 1
fi

touch "$LOCKFILE"

SCREENSHOT_FOLDER="$(xdg-user-dir PICTURES)/screenshots"
SCREENSHOT_FILENAME="screenshot_$(date "+%Y%m%d_%H%M%S").png"

# make screenshot and save stderr in LOCKFILE
hyprshot -o $SCREENSHOT_FOLDER -f $SCREENSHOT_FILENAME -s -z -m "$@" 2>$LOCKFILE

is_screenshot_cancelled=$(cat $LOCKFILE | grep -c "selection cancelled")

if [[ $is_screenshot_cancelled = 1 ]]; then
    echo "screenshot cancelled"
else
    echo "screenshot successful"
    echo "screenshot saved in: $SCREENSHOT_FOLDER/$SCREENSHOT_FILENAME"
    canberra-gtk-play -i camera-shutter &
fi


rm "$LOCKFILE"
