# Uses the first conda installation found in the following list
export CONDA_PATHS=("$HOME/miniforge/bin/conda" "/opt/miniforge/bin/conda")

function conda {
    echo "Lazy loading conda upon first invocation..."
    unset -f conda  # Elimina la función para que la próxima vez se use el comando real

    for conda_path in "${CONDA_PATHS[@]}"; do
        if [[ -f "$conda_path" ]]; then
            echo "Using Conda installation found in $conda_path"
            eval "$($conda_path shell.bash hook)"
            conda "$@"
            return
        fi
    done

    echo "No conda installation found in ${CONDA_PATHS[*]}"
    return 1
}
