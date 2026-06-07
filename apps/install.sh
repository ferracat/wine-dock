#!/bin/bash
# Silent installation during docker build (apps/Dockerfile).
# Installs every file in /home/$USER/installers/ (except .gitkeep).
# Env: INSTALL_ARGS, USER_NAME, INSTALL_TIMEOUT, WINEPREFIX
# INSTALL_ARGS: empty = auto per file (.exe=/S, .msi=/quiet);
#               one value = same flags for all; "arg1|arg2" = per file (sorted order).
set -euo pipefail

USER_NAME="${USER_NAME:-wine}"
INSTALL_ARGS="${INSTALL_ARGS:-}"
INSTALL_TIMEOUT="${INSTALL_TIMEOUT:-1800}"
INSTALLERS_DIR="/home/${USER_NAME}/installers"
log="/tmp/install.log"

export WINEDEBUG="${WINEDEBUG:--all,+err,+warn}"

auto_install_args() {
    case "${1##*.}" in
        msi|MSI) printf '%s' '/quiet' ;;
        exe|EXE) printf '%s' '/S' ;;
    esac
}

mapfile -t installer_files < <(
    find "$INSTALLERS_DIR" -maxdepth 1 -type f ! -name '.gitkeep' | sort
)

if [ "${#installer_files[@]}" -eq 0 ]; then
    echo "ERROR: no installers in ${INSTALLERS_DIR}" >&2
    exit 1
fi

declare -a file_args=()
if [ -n "$INSTALL_ARGS" ] && [[ "$INSTALL_ARGS" == *"|"* ]]; then
    IFS='|' read -ra file_args <<< "$INSTALL_ARGS"
elif [ -n "$INSTALL_ARGS" ]; then
    for _ in "${installer_files[@]}"; do
        file_args+=("$INSTALL_ARGS")
    done
else
    for inst in "${installer_files[@]}"; do
        file_args+=("$(auto_install_args "$(basename "$inst")")")
    done
fi

(
    set -eux
    echo "=== Wine installation (build) ==="
    echo "Installers dir: ${INSTALLERS_DIR}"
    echo "Count: ${#installer_files[@]}"
    echo "Timeout per installer: ${INSTALL_TIMEOUT}s"
    echo "WINEPREFIX: ${WINEPREFIX:-?}"
    echo "Started: $(date -Is)"
    echo ""

    for i in "${!installer_files[@]}"; do
        inst="${installer_files[$i]}"
        args="${file_args[$i]:-}"
        name="$(basename "$inst")"
        echo "--- [$((i + 1))/${#installer_files[@]}] ${name} args: ${args:-<none>} ---"

        export WINE_INST="$inst"
        export WINE_ARGS="$args"
        timeout --foreground "${INSTALL_TIMEOUT}" bash -c '
            case "$(basename "$WINE_INST")" in
                *.msi|*.MSI)
                    # shellcheck disable=SC2086
                    xvfb-run -a msiexec /i "$WINE_INST" $WINE_ARGS
                    ;;
                *)
                    # shellcheck disable=SC2086
                    xvfb-run -a wine "$WINE_INST" $WINE_ARGS
                    ;;
            esac
            wineserver -w 2>/dev/null || true
        '
    done

    echo ""
    echo "Finished: $(date -Is)"
    echo "=== Installation complete ==="
) 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}

if [ "$rc" -eq 124 ]; then
    echo "=== TIMEOUT after ${INSTALL_TIMEOUT}s ===" >&2
    echo "    Increase: make app ... INSTALL_TIMEOUT=3600" >&2
elif [ "$rc" -ne 0 ]; then
    echo "=== Installation failed (exit ${rc}) ===" >&2
fi

if [ "$rc" -ne 0 ]; then
    echo "--- Last lines of log (${log}) ---" >&2
    tail -n 50 "$log" >&2 || true
    echo "--- .exe files under Program Files ---" >&2
    find "${WINEPREFIX:-/home/${USER_NAME}/.wine}/drive_c/Program Files" \
        -maxdepth 5 -name '*.exe' 2>/dev/null | head -30 >&2 || true
    exit "$rc"
fi
