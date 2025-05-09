#!/usr/bin/fish

set -l astal_path "$HOME/.config/astal-widgets/"
set -l widget_path "$astal_path$argv/"

if test -z "$argv"
  echo "missing directory name"
  return 1
end

if test ! -e $widget_path
  echo "directory do not exist"
  return 1
end

if test "ok" = "$(astal -i $argv)"
  astal -i $argv -q
end

cd $astal_path
lua $argv/init.lua
