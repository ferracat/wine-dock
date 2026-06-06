#!/bin/bash
# Start the Wine dev container (evoqued by `make container`)
# Configure via docker.vars in the project root.
set -euo pipefail

_SCRIPTPATH="$(dirname -- "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname -- "$_SCRIPTPATH")"
DOCKER_VARS="$PROJECT_ROOT/docker.vars"

[ -f "$_SCRIPTPATH/functions.sh" ] && source "$_SCRIPTPATH/functions.sh" || {
    echo -e "\033[31mERROR:\033[0m file missing: $_SCRIPTPATH/functions.sh"
    exit 1
}

[ -f "$DOCKER_VARS" ] && source "$DOCKER_VARS" || {
    echo -e "\033[31mERROR:\033[0m file missing: $DOCKER_VARS"
    exit 1
}

if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
    echo -e "\033[31mERROR:\033[0m image '$DOCKER_IMAGE' not found. Execute: make image"
    exit 1
fi

CONTAINER="${1:-$DOCKER_CONTAINER}"
USER_NAME="${DOCKER_USER:-wine}"
_wine_local="${WINE_LOCAL_DIR:-.wine-local}"
[[ "$_wine_local" != /* ]] && _wine_local="$PROJECT_ROOT/$_wine_local"
WINE_LOCAL_DIR="$_wine_local"
DATA_DIR="${DATA_DIR:-$WINE_LOCAL_DIR/data}"
INSTALLERS_DIR="${INSTALLERS_DIR:-$WINE_LOCAL_DIR/installers}"
WINE_DATA_DIR="${WINE_DATA_DIR:-$WINE_LOCAL_DIR/wine-prefix}"

mkdir -p "$DATA_DIR" "$INSTALLERS_DIR" "$WINE_DATA_DIR"

if docker ps -q -f name="^${CONTAINER}$" | grep -q .; then
    echo -e "\033[33mWARNING:\033[0m The container \"$CONTAINER\" is already running."
    exit 0
fi

if docker ps -aq -f name="^${CONTAINER}$" | grep -q .; then
    echo "Starting existing container \"$CONTAINER\"..."
    docker start "$CONTAINER"
    exit 0
fi

docker_cmd=(docker run -dit --name "$CONTAINER" --hostname "$CONTAINER")
while IFS= read -r flag; do docker_cmd+=("$flag"); done < <(container_run_user_flags)
container_add_bind docker_cmd "$WINE_DATA_DIR" "/home/${USER_NAME}/.wine"
container_add_bind docker_cmd "$INSTALLERS_DIR" "/home/${USER_NAME}/installers"
container_add_bind docker_cmd "$DATA_DIR" "/home/${USER_NAME}/data"
docker_cmd+=(
    -e "WINEPREFIX=/home/${USER_NAME}/.wine"
    -e WINE_AUTO_INIT=1
)

read -r -p "Activate graphical support (X11) for Windows applications? [Y/n]: " yn_choice
case "${yn_choice:-Y}" in
    [yY]|"")
        echo "Activating X11..."
        xhost +local:docker 2>/dev/null || true
        container_add_x11_flags docker_cmd "${DISPLAY:-:0}"
        [ -f "${HOME}/.Xauthority" ] && \
            docker_cmd+=(-v "${HOME}/.Xauthority:/home/${USER_NAME}/.Xauthority:ro")
        ;;
    *)
        echo "No X11 (use xvfb-run wine ... for tests without screen)."
        ;;
esac

docker_cmd+=("$DOCKER_IMAGE")

echo "${docker_cmd[*]}"
"${docker_cmd[@]}"

echo ""
echo "Container \"$CONTAINER\" created (user=${USER_NAME})."
echo "  Host data: ${WINE_LOCAL_DIR}/{wine-prefix,data,installers}"
echo "  make attach          # shell in container"
echo "  make winecfg         # winecfg (with X11)"
echo "  make winetricks ARGS=\"vcrun2019\"  # Windows dependencies"
echo "  wine ~/installers/app.exe         # inside the container"
