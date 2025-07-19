#!/bin/bash

audio_source=$1
# turn up (+) or down (-) or mute (mute)
option=$2

if [ "$option" = "mute" ]; then
    wpctl set-mute @$audio_source@ toggle
    exit
fi

# set volume
wpctl set-volume @$audio_source@ 5%$option --limit 1.0
