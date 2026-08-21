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
- **GitHub CLI (`gh`)** - GitHub's official command-line tool
- **Tailwind CSS CLI** - Tailwind CSS v4 command-line compiler, installed globally
- **Claude Code** - Anthropic's official CLI tool for Claude, globally installed
- **omp (Oh My Pi)** - AI coding agent for the terminal (globally installed via Bun with npmmirror)
- **Fish shell** - Default shell with fish configuration
- **Common utilities** - ripgrep, fd-find, tmux, screen, htop, btop, fastfetch, make

### Editing the image

Edit the `Dockerfile` and run `coder templates push` to update workspaces.

## Proxy Configuration

This template supports HTTP/HTTPS proxy configuration during Docker image build. Set the following Terraform variables when needed:

- `http_proxy`
- `https_proxy`
- `no_proxy`

## Local Development

### 构建镜像

在当前 `coder-nvim` 仓库根目录下执行构建：

```bash
docker build --pull --no-cache -t coder-rocky-dev:latest .
```

### 本地开发使用

#### 直接用 docker run 进入交互式 Shell（最快速简单）

当你 clone 了某个项目（假设路径为 `~/projects/my-app`），切换到该项目目录并运行：

```bash
cd ~/projects/my-app

docker run -it --rm \
  -v $(pwd):/home/coder/workspace \
  -w /home/coder/workspace \
  -u coder \
  coder-rocky-dev:latest fish
```

**参数说明**：
- `-v $(pwd):/home/coder/workspace`：将本地项目目录挂载到容器内。
- `-u coder`：以容器内的非 root 用户 `coder` 身份运行。
- 进入后可直接使用 `nvim .` 编辑代码，或直接执行 `bun` / `go` / `cargo` / `omp` / `claude` 等。

## Versioning & Releases

本项目遵循 [Semantic Versioning](https://semver.org/)（`MAJOR.MINOR.PATCH`；release 流程稳定前处于 `0.x` 预发布阶段）。版本号、`CHANGELOG.md` 与 GitHub Release 全部由 [release-please](https://github.com/googleapis/release-please) 根据 [Conventional Commits](https://www.conventionalcommits.org/) 自动管理。

### 发布流程

1. 按提交规范合并若干 PR 到 `master`。
2. release-please 自动开启并维护一个 **Release PR**：聚合变更、递增 `.release-please-manifest.json` 版本号、追加 `CHANGELOG.md`。
3. 合并 Release PR → 自动打 tag `vX.Y.Z`、发布 GitHub Release。
4. `Release` workflow 触发，构建 **多架构**（`linux/amd64` + `linux/arm64`）镜像并推送到 GHCR：

   | 镜像 | 说明 | GHCR 地址 |
   | --- | --- | --- |
   | `rocky-dev` | 本仓库根 `Dockerfile`（完整开发环境） | `ghcr.io/defectingcat/rocky-dev` |
   | `xfy-nvim` | `xfy-nvim/` 子目录（容器化 Neovim） | `ghcr.io/defectingcat/xfy-nvim` |

   每个版本的 tag：`vX.Y.Z`（精确）、`X.Y`（滚动 minor）、`latest`。

拉取已发布镜像：

```bash
docker pull ghcr.io/defectingcat/rocky-dev:latest
docker pull ghcr.io/defectingcat/xfy-nvim:0.1
```

> `main.tf` 的 Coder 模板仍由 Coder 服务端**本地构建**镜像（`coder-rocky-dev:latest`）；GHCR 上的镜像服务于本地 `docker run` / `docker compose` 开发，二者互补。

### Commit 规范

所有提交**必须**遵循 Conventional Commits（PR 上由 commitlint 强制检查）：

| 前缀 | 版本影响 | 示例 |
| --- | --- | --- |
| `feat:` | minor | `feat(dev): add zig toolchain` |
| `fix:` | patch | `fix(docker): retry mirror on 404` |
| `feat!:` / `BREAKING CHANGE` | major（`0.x` 阶段升 minor） | `feat(nvim)!: switch to lazy.nvim` |
| `docs:` `chore:` `ci:` `build:` `refactor:` `test:` | 无（聚合到下次发版） | `ci: bump action versions` |

常用 scope：`dev` `docker` `nvim` `xfy-nvim` `tf` `ci`。

合并 PR 时请使用 **squash merge**，使每个 PR 恰好对应一条 conventional commit。

## CI/CD

| Workflow | 触发 | 作用 |
| --- | --- | --- |
| [`ci.yml`](.github/workflows/ci.yml) | push 到 `master`、PR | commitlint、`terraform fmt/validate`、两个镜像各做 amd64 冒烟构建（不推送） |
| [`release.yml`](.github/workflows/release.yml) | push 到 `master` | release-please 发版 + 多架构构建推送 GHCR |

[Dependabot](.github/dependabot.yml) 每周更新 GitHub Actions 与基础镜像；依赖更新提交使用 `fix(deps)`/`chore(ci)` 前缀，自动汇入正常发版流程。
