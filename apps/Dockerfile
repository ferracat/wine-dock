# Generic Dockerfile: make app APP=name EXE=./installer
# Copies all files from apps/<APP>/installers/ and runs install.sh on each.
# INSTALL_ARGS (make): auto per file; one value for all; or "arg1|arg2" per file (sorted).
# INSTALL_TIMEOUT (make): seconds per installer (default 1800)
ARG BASE_IMAGE=wine-base
FROM ${BASE_IMAGE}

# ARGs declared before FROM are not available here — redeclare after FROM
ARG APP
ARG USER_NAME=wine
ARG INSTALL_ARGS=
ARG INSTALL_TIMEOUT=1800

# --- ROOT ---
USER root
COPY --chmod=755 apps/install.sh /tmp/install.sh
COPY --chown=${USER_NAME}:${USER_NAME} "apps/${APP}/installers/" "/home/${USER_NAME}/installers/"

# --- USER ---
USER ${USER_NAME}

RUN INSTALL_ARGS="${INSTALL_ARGS}" \
    INSTALL_TIMEOUT="${INSTALL_TIMEOUT}" \
    /tmp/install.sh
