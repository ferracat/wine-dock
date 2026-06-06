#!/bin/bash

# Entrypoint for Docker Wine Container
# ------------------------------------
# This script initializes the required environment (WINEPREFIX, X11, etc)
# for running Windows applications via Wine inside the container.
#
# Main functions:
# - Initializes the Wine prefix when necessary
# - Provides support for headless environments via Xvfb if no DISPLAY is available
# - Utility functions for detecting interactive shells and wine-related commands
#
# For details and make targets, see the README.md or Makefile.

set -e


###################################################################################################
# FUNCTION: wine_prefix_ready()
#
# DESCRIPTION:
#   Checks if the Wine Prefix is ready for use.
#
# RETURN:
#   0 (success) if the Wine Prefix is defined, the C: drive exists,
#   and the essential syswow64/kernel32.dll is present.
###################################################################################################
wine_prefix_ready()
{
    [ -n "${WINEPREFIX:-}" ] \
        && [ -d "${WINEPREFIX}/drive_c" ] \
        && [ -f "${WINEPREFIX}/drive_c/windows/syswow64/kernel32.dll" ]
}

###################################################################################################
# FUNCTION: stop_wineserver()
#
# DESCRIPTION:
#   Stops the Wine Server.
#
# RETURN:
#   None.
###################################################################################################
stop_wineserver()
{
    wineserver -k 2>/dev/null || true
}

###################################################################################################
# FUNCTION: init_wine_prefix()
#
# DESCRIPTION:
#   Initializes the Wine Prefix.
#
# RETURN:
#   None.
###################################################################################################
init_wine_prefix()
{
    echo "Initializing WINEPREFIX at ${WINEPREFIX}..."
    local xvfb_pid=""

    # xvfb-run leaves syswow64 incomplete; use host DISPLAY or direct Xvfb.
    if wineboot --init; then
        wineserver -w 2>/dev/null || true
        return
    fi

    echo "wineboot without DISPLAY; using Xvfb :98..." >&2
    set +m
    Xvfb :98 -screen 0 1024x768x16 -nolisten tcp &
    xvfb_pid=$!
    trap 'kill "$xvfb_pid" 2>/dev/null; wait "$xvfb_pid" 2>/dev/null || true' RETURN
    sleep 2
    DISPLAY=:98 wineboot --init
    wineserver -w 2>/dev/null || true
}

###################################################################################################
# FUNCTION: is_interactive_shell()
#
# DESCRIPTION:
#   Checks if the shell is interactive.
#   Only interactive shells: don't block startup (wineboot can take several minutes)
#
# RETURN:
#   None.
###################################################################################################
is_interactive_shell()
{
    case "${1:-}" in
        bash|/bin/bash|sh|/bin/sh|zsh|/bin/zsh) return 0 ;;
        *) return 1 ;;
    esac
}

###################################################################################################
# FUNCTION: needs_wine_prefix()
#
# DESCRIPTION:
#   For explicit wine commands like wine/winetricks, the Wine Prefix is required.
#   This function checks if the command requires a Wine Prefix.
#
# RETURN:
#   None.
###################################################################################################
needs_wine_prefix()
{
    case "${1:-}" in
        wine|wine64|wineboot|winetricks|winecfg|winepath|wineserver|wineconsole) return 0 ;;
        *) return 1 ;;
    esac
}

###################################################################################################
# FUNCTION: run_cmd()
#
# DESCRIPTION:
#   Runs CMD in the foreground under tini (PID 1). SIGTERM/SIGINT stop the wineserver and exit;
#   EXIT only stops the wineserver so the exit code of wine/CMD is preserved.
#
# ARGS:
#   Command and arguments to execute (passed as "$@")
#
# RETURN:
#   Exit status of the command, or 0 on SIGTERM/SIGINT.
###################################################################################################
run_cmd()
{
    trap 'stop_wineserver; exit 0' SIGTERM SIGINT
    trap stop_wineserver EXIT
    "$@"
}


# -------------------------------------------------------------------------------------------------
# ---                                          MAIN                                             ---
# -------------------------------------------------------------------------------------------------

if ! wine_prefix_ready; then
    if [ "${WINE_AUTO_INIT:-0}" = "1" ]; then
        init_wine_prefix || true
    elif [ $# -gt 0 ] && needs_wine_prefix "$1"; then
        init_wine_prefix
    elif [ $# -gt 0 ] && is_interactive_shell "$1"; then
        echo "WINEPREFIX not initialized yet. Inside the container: wineboot --init"
        echo "(or start with WINE_AUTO_INIT=1)"
    fi
fi

if [ $# -gt 0 ]; then
    run_cmd "$@"
fi
