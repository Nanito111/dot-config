function kitty-config --wraps='cd ~/.config/kitty; nvim kitty.conf' --description 'alias kitty-config=cd ~/.config/kitty; nvim kitty.conf'
  cd ~/.config/kitty; nvim kitty.conf $argv
        
end
