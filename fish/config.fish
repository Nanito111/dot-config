if status is-interactive
    # Commands to run in interactive sessions can go here
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/nanito/mambaforge-pypy3/bin/conda
    status is-interactive && eval /home/nanito/mambaforge-pypy3/bin/conda "shell.fish" "hook" $argv | source
end

if test -f "/home/nanito/mambaforge-pypy3/etc/fish/conf.d/mamba.fish"
    source "/home/nanito/mambaforge-pypy3/etc/fish/conf.d/mamba.fish"
end
# <<< conda initialize <<<

starship init fish | source
