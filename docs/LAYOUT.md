# wine-dock layout

## `bin/` vs `.runtime/`

| Directory | Role | Invoked by |
|-----------|------|------------|
| **`bin/`** | User-facing commands and Makefile utilities | You, `make`, `~/.local/bin` wrappers |
| **`.runtime/`** | Shared library code + dev container startup | Scripts in `bin/`, `make container` |

```text
make / user
     │
     ▼
  bin/                              ← public entry points
     │
     ├── wine-launch ──────────────► .runtime/functions.sh
     │                                    (Docker, X11, Podman)
     ├── install-cmd ───┐
     ├── install-desktop ├──► .runtime/colors.sh + messages.sh
     ├── scaffold-app ───┘
     │
     └── resolve-install-args        (standalone; no .runtime/)

make container ──► .runtime/run.sh ──► functions.sh, docker.vars
```

### `bin/`

| Script | Purpose | `.runtime/` |
|--------|---------|-------------|
| `wine-launch` | Run a Windows app (`docker run`, prefix, X11) | `functions.sh` |
| `install-cmd` | Install `~/.local/bin/<app>` wrapper | `colors.sh`, `messages.sh` |
| `install-desktop` | Install freedesktop `.desktop` launcher | `colors.sh`, `messages.sh` |
| `scaffold-app` | `make app-init` — create `apps/<name>/` | `colors.sh`, `messages.sh` |
| `resolve-install-args` | Map `.exe`→`/S`, `.msi`→`/quiet` for `make app` | — |

### `.runtime/`

| File | Purpose |
|------|---------|
| `functions.sh` | Docker/Podman helpers (X11, bind mounts, `keep-id`, `:U`) |
| `run.sh` | Long-lived **development** container (`make container`) |
| `colors.sh`, `messages.sh` | Terminal colours and error helpers |

The leading dot on `.runtime` signals “internal plumbing”, not the main product API.

## `apps/`

| Path | Purpose |
|------|---------|
| `apps/Dockerfile` + `install.sh` | Generic image build from installers (`make app`) |
| `apps/Dockerfile.prefix` | Bake `apps/<app>/wine-prefix/` into an image (`make app-from-prefix`) |
| `apps/<app>/app.vars` | Per-app config: image name, prefix mode, `APP_EXE`, desktop metadata |
| `apps/_template/` | Scaffold for `make app-init` (`app.vars`, optional `Dockerfile`) |
| `apps/example/` | Sample app (Notepad); safe to ship in the repo |
| `apps/<your-app>/` | Your app — **no vendor brands required in examples** |

Optional overrides (used by Makefile when present): `apps/<app>/Dockerfile` instead of `apps/Dockerfile`, and `apps/<app>/Dockerfile.prefix` instead of `apps/Dockerfile.prefix`.

Gitignored per app: `installers/`, `wine-prefix/`, `data/`. Dev container data: `.wine-local/`.

## `sources/`

| Path | Purpose |
|------|---------|
| `sources/wine-mono/COPYING` | Upstream license text (committed) |
| `sources/wine-mono/README` | Wine Mono version, download URL, build-arg override |
| `sources/dlls/` | Optional vendor DLLs copied into base image prefix at `make image` |

Not committed: `sources/dlls/*.dll`, `sources/*.msi`, `sources/*.7z.*` — Wine Mono MSI and **tini** are
downloaded in `Dockerfile` at build time. See README → *Third-party software*.
