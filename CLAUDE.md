# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A general-purpose dev container for running Claude Code in an isolated environment. The container is defined in `.devcontainer/devcontainer.json` and managed via `make` targets that wrap the `devcontainer` CLI.

## Common commands

```sh
make shell                            # start container and open a shell (default workspace = repo root)
make build                            # rebuild, removing the existing container
make build NO_CACHE=1                 # rebuild without Docker layer cache
make down                             # stop and remove the container
make shell WORKSPACE=~/path/to/repo   # open a shell pointed at a different workspace
```

`make shell` runs `make up` first, so it is safe to call without a running container.

## Architecture

### SSH agent forwarding

1Password SSH credentials are forwarded into the container through two socat relays:

- **Host** (`initializeCommand`): `.devcontainer/host-1password-relay.sh` kills any existing relay and starts `socat TCP-LISTEN:2222 ↔ ~/.1password/agent.sock`.
- **Container** (`postStartCommand`): starts `socat UNIX-LISTEN:/tmp/1password-agent.sock ↔ TCP:host.docker.internal:2222` as a background daemon via `start-stop-daemon` (with `--oknodo` so re-starts don't fail). Logs go to `/tmp/1password-relay.log`.
- `SSH_AUTH_SOCK` inside the container is set to `/tmp/1password-agent.sock`.

### Key devcontainer config choices

- Base image: `mcr.microsoft.com/devcontainers/base:ubuntu26.04`
- Claude Code is installed via the Anthropic devcontainer feature (`ghcr.io/anthropics/devcontainer-features/claude-code:1.0`).
- Git config and nvim config are bind-mounted from the host (`~/.config/git`, `~/dotfiles/nvim`).
- Claude config (`~/.claude`) is stored in a named Docker volume (`claude-code-config-<devcontainerId>`) so it persists across rebuilds.
- Dotfiles are applied at `up` time via `--dotfiles-repository https://github.com/xortim/dotfiles`.
- `DISABLE_AUTOUPDATER=1` prevents Claude Code from auto-updating inside the container.
