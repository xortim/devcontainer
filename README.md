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
make shell                            # start container and open a shell
make build                            # rebuild (removes existing container)
make build NO_CACHE=1                 # rebuild without Docker layer cache
make down                             # stop and remove the container
make shell WORKSPACE=~/path/to/repo   # open a shell with a different workspace
```

## SSH agent forwarding

On container start, `initializeCommand` runs a socat relay on the host that
forwards TCP port 2222 to the 1Password SSH agent socket. Inside the container,
a second socat relay connects that port to a Unix socket at
`/tmp/1password-agent.sock`, which is set as `SSH_AUTH_SOCK`. Git and SSH
commands inside the container authenticate through 1Password on your host.
