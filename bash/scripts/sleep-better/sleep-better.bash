#!/bin/bash

notify-send "Good night..." "Sleep-better process is starting. System will be shutdown." \
    -i system-suspend -a "Sleep-better"

ffplay "$CUSTOM_SCRIPTS_DIR/sleep-better/soft-outro-piano.mp3" -nodisp -autoexit

shutdown now
