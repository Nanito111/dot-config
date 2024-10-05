function nvim-config --wraps='cd /home/nanito/.config/nvim/lua/custom; nvim' --wraps=cd\ \'/home/nanito/.config/nvim/lua\'\;\ nvim --wraps='cd ~/.config/nvim/lua/;nvim' --wraps='cd ~/.config/nvim/lua/;nvim .' --description 'alias nvim-config cd ~/.config/nvim/lua/;nvim'
  cd ~/.config/nvim/lua/;nvim $argv
        
end
