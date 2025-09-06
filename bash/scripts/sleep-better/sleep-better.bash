#!/bin/bash

notify-send "Good night..." "Sleep-better process is starting. System will be shutdown." \
    -i system-suspend -a "Sleep-better" -t 2000

canberra-gtk-play -i _desktop-logout

shutdown now
