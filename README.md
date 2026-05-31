# devcontainer

A general-purpose dev container for running Claude Code in an isolated environment.

## What's inside

- Claude Code CLI (via Anthropic's devcontainer feature)
- Node.js, neovim, git, socat
- Personal dotfiles (cloned from [xortim/dotfiles](https://github.com/xortim/dotfiles))
- 1Password SSH agent forwarding via TCP relay

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [devcontainer CLI](https://github.com/devcontainers/cli): `brew install devcontainer`
- [socat](http://www.dest-unreach.org/socat/): `brew install socat`
- [1Password](https://1password.com/) with the SSH agent enabled

## Usage

```sh
make shell                              # start container and open a shell
make build                              # rebuild (removes existing container)
make build-no-cache                     # rebuild without Docker layer cache
make down                               # stop and remove the container
make -C ~/workspace/devcontainer shell  # run from another dir — that dir becomes the workspace
make shell WORKSPACE=~/path/to/repo     # explicit workspace override
make shell-local                        # start with host ~/.claude bind-mounted
make down-local                         # stop the host-~/.claude container
make build-local                        # rebuild the host-~/.claude container
make build-local-no-cache               # rebuild the host-~/.claude container without cache
make migrate-claude                     # copy ~/.claude from Docker volume to host
```

## Using from another repository

The Makefile sets `WORKSPACE` to the directory you invoke `make` from, so you can use this devcontainer with any repo without adding files to it.

**From inside the target repo:**

```sh
cd ~/workspace/myproject
make -C ~/workspace/devcontainer shell          # default Claude volume
make -C ~/workspace/devcontainer shell-local    # host ~/.claude bind-mounted
make -C ~/workspace/devcontainer down           # stop the container
```

**From anywhere with an explicit path:**

```sh
make -C ~/workspace/devcontainer shell WORKSPACE=~/workspace/myproject
make -C ~/workspace/devcontainer shell-local WORKSPACE=~/workspace/myproject
```

All targets (`shell`, `shell-local`, `build`, `down`, `down-local`, `migrate-claude`) accept `WORKSPACE`. The devcontainer CLI uses it as both the mount point inside the container and the label it stamps on the Docker container, so `down` and `migrate-claude` must be given the same `WORKSPACE` value that was used at `shell` / `build` time.

## Claude configuration

By default, `~/.claude` inside the container is backed by a named Docker volume (`claude-code-config-<devcontainerId>`), keeping each container's config isolated and persistent across rebuilds.

Use the `*-local` targets to bind-mount your host `~/.claude` instead:

```sh
make shell-local            # start and enter the container
make down-local             # stop it
make build-local            # rebuild it
make build-local-no-cache   # rebuild without Docker layer cache
```

This gives the container direct access to MCP auth tokens, Bedrock credentials, and any other config managed on the host — and lets multiple devcontainers share the same Claude state. Host `~/.claude` must already exist; the Makefile will error with instructions if it doesn't.

> **Caution:** Do not run `make shell-local` in two repos at the same time. Both containers mount the same host `~/.claude`, including SQLite databases Claude uses for internal state. Concurrent writes without inter-process locking can corrupt that state.

### Migrating from volume to local config

If you have existing Claude config in the default Docker volume and want to carry it to your host, run this once **before** switching to the local targets:

```sh
make migrate-claude
```

This copies `~/.claude` contents from the devcontainer's Docker volume to `~/.claude` on your Mac using a scratch Alpine container. The original volume is left intact.

## SSH agent forwarding

On container start, `initializeCommand` runs a socat relay on the host that
forwards TCP port 2222 to the 1Password SSH agent socket. Inside the container,
a second socat relay connects that port to a Unix socket at
`/tmp/1password-agent.sock`, which is set as `SSH_AUTH_SOCK`. Git and SSH
commands inside the container authenticate through 1Password on your host.
