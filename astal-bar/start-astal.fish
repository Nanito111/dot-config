#!/usr/bin/fish

if test -n "$(astal -l)"
  astal -q
end

cd $HOME/.config/astal-bar/
lua init.lua
