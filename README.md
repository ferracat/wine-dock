# wine-dock

Run **Windows applications on Linux like native commands** — Docker images with Wine,
silent installers, and a CLI/desktop launcher.

## Overview (two phases)

```text
PHASE 1 — Build (Makefile)
  make image                    → wine-base image (Wine only)
  make app APP=x EXE=…          → wine-app-x (silent installer at build time)
  make app-from-prefix APP=x    → wine-app-x (copy existing Wine prefix into image)

PHASE 2 — Run (like a Linux app)
  make install-cmd APP=x        → ~/.local/bin/x
  x                             → docker run + wine app.exe
```

### Where the Wine prefix lives

At **runtime**, Wine only needs a valid prefix — in the image or on the host.
Behaviour is the same; the trade-off is **disk space** vs **portability**.

```text
                    BUILD                         RUNTIME (wine-launch)
                    ─────                         ───────────────────

Mode A — local      (optional)                    wine-base
(dev / repo)        apps/x/wine-prefix/  ─mount─►  + WINE_DATA_DIR=@app
                    copy on the host              host prefix overrides image

Mode B — image      wine-app-x                    wine-app-x
(distribution)      COPY wine-prefix/             + WINE_DATA_DIR=@image
                    prefix inside image           no bind mount — use image prefix
```

| Mode | `APP_IMAGE` | `WINE_DATA_DIR` | Active prefix | Use case |
|------|-------------|-----------------|---------------|----------|
| **A — local** | `wine-base` | `@app` | `apps/<app>/wine-prefix/` | Development; avoid GB duplicated in images |
| **A′ — per user** | `wine-base` | *(unset)* or `~/.local/share/…` | user data dir | Persistent data outside the repo |
| **B — distribution** | `wine-app-<app>` | `@image` | inside the image | `docker push`, `docker save`, another machine |

**Do not duplicate:** Mode A (`@app` + `wine-base`) makes `wine-app-x` optional (only for publishing).
Mode B (`@image`) does not need `wine-prefix/` on the host.

Configure in `apps/<app>/app.vars` — see [§4](#4-daily-use).

## Requirements

- Docker (or Podman with compatible `docker` CLI)
- Graphical session if the app has a GUI (`DISPLAY` set)
- ~2 GB free disk for the base image

## 1. Base image (once)

```bash
cd wine-dock
make help
make image
# with winetricks: make image-full
```

Builds `wine-base` (see `docker.vars`). First build takes several minutes.

At build time the Dockerfile downloads **Wine Mono** and **tini** (not vendored in git); optional vendor
DLLs go in `sources/dlls/` — see [Third-party software](#third-party-software). Override Wine Mono version:
`docker build --build-arg WINE_MONO_VERSION=11.0.0 -t wine-base .`

Container user is `wine` (paths under `/home/wine/…`). `make image` passes your host UID/GID for volume permissions.

## 2. App with an installer

### Quick start

```bash
make app-init APP=myapp
make app APP=myapp EXE=./Setup.msi
# edit APP_EXE in apps/myapp/app.vars (or pass APP_EXE= on make app)
make install-cmd APP=myapp
myapp
```

### Installer vs `APP_EXE`

| | Installer (`setup.exe` / `setup.msi`) | `APP_EXE` (installed program) |
|---|--------------------------------------|----------------------------------|
| **Purpose** | Docker image build (silent install) | Daily command (`wine-launch` / `~/.local/bin/myapp`) |
| **Location** | `apps/<app>/installers/` or `EXE=` on `make app` | `apps/<app>/app.vars` |
| **In `app.vars`?** | **No** — detected by `make app` | **Yes** — placeholder from `app-init`; fix after install |
| **Automatic** | `INSTALL_ARGS` (`/S` or `/quiet`) saved by `make app` | Optional `APP_EXE='C:\…'` on `make app` |

**`INSTALL_ARGS`:** auto per file (`.exe`→`/S`, `.msi`→`/quiet`); one value for all installers;
`arg1|arg2` = one per file (alphabetical order in `installers/`).

**Multiple installers:** put all files in `apps/<app>/installers/` — the build runs **each** file.
Example: `vcredist.exe` + `setup.msi`, then `make app APP=myapp`.

**Headless build:** runs under Xvfb (no windows on your screen). Logs show start/end, args, and Wine progress
(`WINEDEBUG=+err,+warn`). Default timeout **30 min** (`INSTALL_TIMEOUT=1800`).

### Interactive installer (manual prefix)

When the setup is **not** silent (license, wizard, etc.):

```bash
make app-init APP=myapp
make container && make attach
# install in Wine with X11, then edit APP_EXE in apps/myapp/app.vars

# Mode A — local prefix in repo
#   app.vars: APP_IMAGE=wine-base  WINE_DATA_DIR=@app
make install-cmd APP=myapp
myapp

# Mode B — publish image with prefix inside
make app-from-prefix APP=myapp
# on another machine: APP_IMAGE=wine-app-myapp  WINE_DATA_DIR=@image
make install-cmd APP=myapp
myapp
```

| Command | Description |
|---------|-------------|
| `make app-from-prefix APP=x` | Sync dev prefix → `apps/x/wine-prefix/` + build `wine-app-x` |
| `SYNC_PREFIX=0` | Do not sync — use existing `apps/x/wine-prefix/` |
| `PREFIX_SRC=/other/path` | Alternative source instead of `.wine-local/wine-prefix` |

**Manual rsync:** `rsync -a --delete .wine-local/wine-prefix/ apps/myapp/wine-prefix/`

**Common mistake:** `rsync … wine-prefix apps/myapp/wine-prefix/` creates `wine-prefix/wine-prefix/`.
Use `source/` → `apps/x/wine-prefix/` or copy the whole folder to `apps/x/`.

## 3. Quick demo (no installer)

Windows Notepad via Wine (sample app `example`):

```bash
make demo
make install-cmd APP=example
example
```

(`make demo` = `wine-base` + minimal `wine-app-example` image.)

## 4. Daily use

### Mode A — local (recommended for development)

Prefix in the repo; base image without duplicating gigabytes:

```bash
# apps/myapp/app.vars
APP_IMAGE=wine-base
WINE_DATA_DIR=@app

make install-cmd APP=myapp
myapp
```

### Mode B — self-contained image (registry / another machine)

Prefix **inside** `wine-app-myapp`; no host folder:

```bash
make app-from-prefix APP=myapp

# apps/myapp/app.vars (on target machine)
APP_IMAGE=wine-app-myapp
WINE_DATA_DIR=@image

make install-cmd APP=myapp
myapp
```

Export without a registry:

```bash
docker save wine-app-myapp | gzip > myapp.tar.gz
# elsewhere: docker load < myapp.tar.gz
```

### `WINE_DATA_DIR` reference

| Value | Effect |
|-------|--------|
| `@app` | Bind mount `apps/<app>/wine-prefix/` |
| `@image` | No mount — prefix from `APP_IMAGE` |
| *(unset)* | `@app` if valid prefix exists; else `~/.local/share/wine-docker/<app>/` |
| absolute / relative path | Bind mount that directory |

```bash
make install-cmd APP=myapp       # terminal command
make install-desktop APP=myapp   # menu / dock launcher
make install APP=myapp           # both
```

Optional in `app.vars`: `APP_DISPLAY_NAME`, `APP_CATEGORIES`, `APP_ICON=apps/myapp/icon.png`,
`EXTRA_DOCKER_ARGS` (e.g. `--device=/dev/bus/usb` for USB hardware).

Test without installing to PATH:

```bash
./bin/wine-launch myapp
```

## Project layout

```text
wine-dock/
  Dockerfile, Dockerfile.full   # base image (downloads Wine Mono + tini at build)
  Makefile, docker.vars, entrypoint.sh
  run → .runtime/run.sh           # shortcut (make container)
  docs/LAYOUT.md                  # bin/ vs .runtime/ detail
  sources/
    wine-mono/COPYING             # Wine Mono license (MSI downloaded at build)
    dlls/                         # optional vendor DLLs (gitignored *.dll)
  .runtime/                       # internal helpers (not user-facing)
    run.sh                          # dev container (make container)
    functions.sh                    # shared Docker/Podman helpers
    colors.sh, messages.sh
  .wine-local/                      # dev container data (gitignored)
  bin/                              # commands invoked by you / Makefile
    wine-launch                     # run apps (PHASE 2)
    install-cmd, install-desktop
    scaffold-app, resolve-install-args
  apps/
    Dockerfile, install.sh          # generic silent install build
    Dockerfile.prefix               # build from apps/<app>/wine-prefix/
    _template/                      # scaffold for new apps
    example/                          # sample app (Notepad demo)
      app.vars
    <your-app>/
      app.vars
      installers/                   # gitignored
      wine-prefix/                  # Mode A; gitignored
```

See [docs/LAYOUT.md](docs/LAYOUT.md) for `bin/` vs `.runtime/` in more detail.

## Make targets

| Command | Description |
|---------|-------------|
| `make help` | List targets |
| `make image` | Base image `wine-base` |
| `make image-full` | Base + winetricks |
| `make app APP=x EXE=y` | App image (silent installer) |
| `make app-from-prefix APP=x` | Image from dev prefix |
| `make app-init APP=x` | Create `apps/x/` only |
| `make app-setup APP=x EXE=y` | `app` + `install-cmd` |
| `make app-from-prefix-setup APP=x` | `app-from-prefix` + `install-cmd` |
| `make install-cmd APP=x` | Command on PATH |
| `make install-desktop APP=x` | Menu `.desktop` entry |
| `make install APP=x` | `install-cmd` + `install-desktop` |
| `make show-apps` | List apps under `apps/` |
| `make demo` | Build `example` (Notepad) |
| `make container` / `make attach` | Long-lived dev shell |

Variables: `EXE`, `APP_EXE`, `INSTALL_ARGS`, `INSTALL_TIMEOUT`, `INSTALL_BIN`, `USER_NAME`, `SYNC_PREFIX`, `NO_CACHE`.

## Dev container (optional)

Persistent shell container — not the “command on PATH” flow:

```bash
make container    # run → .runtime/run.sh, prompts for X11
make attach
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `wine-base` / `wine-app-x` not found | `make image` / `make app-from-prefix APP=x` |
| Empty prefix / Mono prompt | Mode A: `WINE_DATA_DIR=@app` + valid `apps/x/wine-prefix/` |
| Disk duplication | Mode A: `wine-base` + `@app`; Mode B: `wine-app-x` + `@image` |
| MIT-SHM / `X_ShmPutImage` / `BadValue` | Recreate dev container with X11; `wine-launch` uses `--ipc=host` + `QT_X11_NO_MITSHM=1` |
| Window does not open | Check `echo $DISPLAY`; graphical session required |
| `APP_EXE missing` | Edit `apps/<app>/app.vars` after installing in Wine |
| Permissions | Rebuild image (`make image`) on a new machine; container user is `wine` |

## Third-party software

This repository provides **tooling only**. Windows applications and their installers are your
responsibility regarding licenses and redistribution. The included `example` app uses Windows
Notepad for demonstration only.

**Wine Mono** — not committed to git. `make image` downloads the official MSI from
[wine-mono releases](https://github.com/wine-mono/wine-mono/releases) (default `10.1.0`).
License text: `sources/wine-mono/COPYING` (MIT / LGPL / MS-PL mix; see upstream `COPYING`).

**tini** v0.19.0 — not committed to git. `make image` downloads the binary from
[krallin/tini releases](https://github.com/krallin/tini/releases) (container PID 1 init).
[MIT License](https://github.com/krallin/tini/blob/v0.19.0/LICENSE).

**`sources/dlls/*.dll`** — optional vendor DLLs (e.g. `msvbvm60.dll`); **not redistributed**
in this repo (gitignored). Drop any needed `.dll` files into `sources/dlls/` before `make image`;
build succeeds with an empty directory. Obtain binaries under the vendor's redistribution terms,
or install via `winetricks` inside a dev container.
