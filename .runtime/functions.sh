#!/bin/bash
# Shared Docker/Podman helpers for wine container run scripts.
# shellcheck shell=bash

_SCRIPTPATH="$(dirname -- "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=colors.sh
source "$_SCRIPTPATH/colors.sh"
# shellcheck source=messages.sh
source "$_SCRIPTPATH/messages.sh"


container_engine_is_podman() {
    docker version 2>/dev/null | grep -qi podman
}

# Podman rootless: chown bind-mount contents to the container user.
container_vol_uidmap() {
    container_engine_is_podman && echo ':U'
}

# Podman rootless: run with the host UID/GID inside the user namespace.
container_run_user_flags() {
    if container_engine_is_podman; then
        printf '%s\n' --userns=keep-id
    fi
}

# Append X11 flags for GUI apps (socket mount + MIT-SHM workarounds in containers).
# Usage: container_add_x11_flags _cmd_array [display]
container_add_x11_flags() {
    local -n _cmd=$1
    local display="${2:-${DISPLAY:-:0}}"
    _cmd+=(
        -e "DISPLAY=${display}"
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw
        --ipc=host
        -e QT_X11_NO_MITSHM=1
    )
}

# Append standard bind-mount flags to a docker run command array.
# Usage: container_add_bind _cmd_array host_path container_path
container_add_bind() {
    local -n _cmd=$1
    local host_path=$2
    local container_path=$3
    local uidmap
    uidmap="$(container_vol_uidmap)"
    _cmd+=(-v "${host_path}:${container_path}${uidmap}")
}

# Require a running container with X11 support (socket mount + host DISPLAY).
# Usage: container_require_x11 [container_name]
container_require_x11() {
    local container="${1:?container name required}"

    docker ps -q -f name="^${container}$" | grep -q . || {
        err_msg "Container ${WHITE}'${container}'${NC} is not running. Execute \`make container\`" $LINENO "${BASH_SOURCE[0]}"
        return 1
    }

    docker inspect "${container}" \
        --format '{{range .Mounts}}{{if eq .Destination "/tmp/.X11-unix"}}ok{{end}}{{end}}' | grep -q ok || {
            warn_msg "Container without graphical support (/tmp/.X11-unix not mounted)." $LINENO "${BASH_SOURCE[0]}"
            echo -e "         Recreate with \`make clean && make container\` and answer Y to X11"
        return 1
    }

    [ -n "${DISPLAY:-}" ] || {
        warn_msg "DISPLAY environment variable not defined on host." $LINENO "${BASH_SOURCE[0]}"
        return 1
    }
}
