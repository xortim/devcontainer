#!/bin/bash
# Relay 1Password SSH agent socket over TCP so the dev container can reach it.
# Runs on the macOS host via devcontainer initializeCommand.
pkill -f "socat TCP-LISTEN:2222" 2>/dev/null || true
socat TCP-LISTEN:2222,fork,reuseaddr \
  UNIX-CONNECT:"$HOME/.1password/agent.sock" &
