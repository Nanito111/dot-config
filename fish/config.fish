if status is-interactive
    # Commands to run in interactive sessions can go here
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/francisco/miniforge3/bin/conda
    eval /home/francisco/miniforge3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/francisco/miniforge3/etc/fish/conf.d/conda.fish"
        . "/home/francisco/miniforge3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/francisco/miniforge3/bin" $PATH
    end
end

if test -f "/home/francisco/miniforge3/etc/fish/conf.d/mamba.fish"
    source "/home/francisco/miniforge3/etc/fish/conf.d/mamba.fish"
end
# <<< conda initialize <<<

starship init fish | source
