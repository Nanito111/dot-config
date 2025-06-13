#!/bin/bash

notify-send "Good night..." "Sleep-better process is starting. System will be shutdown." \
  -i system-suspend -a "Sleep-better"

ffplay $HOME/.config/sleep-better/sleep-song.ogg -autoexit -nodisp

shutdown now
