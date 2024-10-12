function starship-config --wraps='cd ~/.config/ & nvim starship.toml' --description 'alias starship-config cd ~/.config/ & nvim starship.toml'
  cd ~/.config/ & nvim starship.toml $argv
        
end
