function astal-bar --wraps='lua ~/.config/astal-bar/init.lua' --wraps='cd ~/.config/astal-bar && lua init.lua' --description 'alias astal-bar=cd ~/.config/astal-bar && lua init.lua'
  cd ~/.config/astal-bar && lua init.lua $argv
        
end
