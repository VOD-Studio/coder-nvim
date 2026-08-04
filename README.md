---
display_name: Rocky Linux Dev Environment
description: Provision Rocky Linux containers with Neovim, Go, Rust, Node.js as Coder workspaces
icon: ../../../site/static/icon/docker.png
maintainer_github: coder
verified: true
tags: [docker, container, rocky, neovim, go, rust]
---

# Remote Development on Rocky Linux Containers

Provision Rocky Linux containers as [Coder workspaces](https://coder.com/docs/workspaces) with this template.

## Prerequisites

### Infrastructure

The VM you run Coder on must have a running Docker socket and the `coder` user must be added to the Docker group:

```sh
# Add coder user to Docker group
sudo adduser coder docker

# Restart Coder server
sudo systemctl restart coder

# Test Docker
sudo -u coder docker ps
```

## Architecture

This template provisions the following resources:

- Docker image (built by Docker socket and kept locally)
- Docker container pod (ephemeral)
- Docker volume (persistent on `/home/coder`)

This means, when the workspace restarts, any tools or files outside of the home directory are not persisted. To pre-bake tools into the workspace, modify the container image. Alternatively, individual developers can [personalize](https://coder.com/docs/dotfiles) their workspaces with dotfiles.

> **Note**
> This template is designed to be a starting point! Edit the Terraform to extend the template to support your use case.

## Development Tools

This workspace includes:

- **Neovim v0.12.1** - Modern Vim editor with Lazy.nvim plugin manager
- **Go 1.26.2** - Go programming language
- **Rust** - With USTC crates.io and rustup mirrors configured
- **Node.js (fnm)** - Fast Node Manager for Node.js version management
- **Bun** - Fast all-in-one JavaScript runtime & toolkit (latest)
- **Claude Code** - Anthropic's official CLI tool for Claude, globally installed
- **omp (Oh My Pi)** - AI coding agent for the terminal (globally installed via Bun with npmmirror)
- **Fish shell** - Default shell with fish configuration
- **Common utilities** - ripgrep, fd-find, tmux, screen, htop, fastfetch, make

### Editing the image

Edit the `Dockerfile` and run `coder templates push` to update workspaces.

## Proxy Configuration

This template supports HTTP/HTTPS proxy configuration during Docker image build. Set the following Terraform variables when needed:

- `http_proxy`
- `https_proxy`
- `no_proxy`

## Build locally

```sh
docker build --progress=plain -t coder-rocky-dev .
```

```sh
docker build --force --progress=plain -t coder-rocky-dev .
```

```sh
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  coder-rocky-dev:latest
```

