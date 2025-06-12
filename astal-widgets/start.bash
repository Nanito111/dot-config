#!/bin/bash

# Define paths
astal_path="$HOME/.config/astal-widgets/"
widget_path="$astal_path$1/"

# Check if directory name is provided
if [ -z "$1" ]; then
  echo "missing directory name"
  exit 1
fi

# Check if the directory exists
if [ ! -e "$widget_path" ]; then
  echo "directory does not exist"
  exit 1
fi

# Check if the widget is already installed
if [ "ok" = "$(astal -i "$1")" ]; then
  astal -i "$1" -q
fi

# Change to the astal path and execute the Lua script
cd "$astal_path" || exit
lua "$1/init.lua"
