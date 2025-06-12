save-alias() {
  local alias_dir="$HOME/.config/bash/"
  local alias_file="$alias_dir/aliases.bash"

  # append the alias to the file
  echo "alias $*" >> "$alias_file"

  echo "Alias saved to $alias_file"
}

# usage
# save-alias ll='ls -l'
