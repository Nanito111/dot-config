#!/bin/bash

notify-send "Good night..." "Sleep-better process is starting. System will be shutdown." \
    -i system-suspend -a "Sleep-better"

ffplay "$BASH_CONFIG_DIR/scripts/sleep-better/sleep-audio.ogg" -nodisp -autoexit &
ffplay "$BASH_CONFIG_DIR/scripts/sleep-better/sleep-song.ogg" -nodisp -autoexit

shutdown now
