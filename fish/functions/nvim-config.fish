function nvim-config --wraps='cd /home/nanito/.config/nvim/lua/custom; nvim' --wraps=cd\ \'/home/nanito/.config/nvim/lua\'\;\ nvim --description alias\ nvim-config=cd\ \'/home/nanito/.config/nvim/lua\'\;\ nvim
  cd '/home/nanito/.config/nvim/lua'; nvim $argv
        
end
