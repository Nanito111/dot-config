#!/bin/bash

notify-send "Good night..." "Sleep-better process is starting. System will be shutdown." \
    -i system-suspend -a "Sleep-better"

ffplay "$BASH_CONFIG_DIR/scripts/sleep-better/soft-outro-piano.mp3" -nodisp -autoexit

shutdown now
