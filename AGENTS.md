<!-- Generated: 2026-04-21 | Updated: 2026-04-21 -->

# coder-nvim

## Purpose
Coder workspace template that provisions Rocky Linux 9 containers as remote development environments. Uses Terraform to orchestrate Docker resources and a multi-stage Dockerfile to build a dev image with Neovim, Go, Rust, Node.js, Bun, Claude Code, and omp (Oh My Pi).

## Key Files
| File | Description |
|------|-------------|
| `Dockerfile` | Multi-stage build: compiles Neovim v0.12.1, downloads Go, then assembles runtime image with all dev tools |
| `main.tf` | Terraform config defining Coder workspace: agent, Docker image/container/volume, code-server module, proxy variables |
| `README.md` | Template documentation with prerequisites, architecture, and tool list |
| `.gitignore` | Excludes `.omc/` directory |

## For AI Agents

### Working In This Directory
- Dockerfile uses USTC mirrors for Rocky, EPEL, Rust, and crates.io — do not replace with default URLs
- The Dockerfile has two stages: `builder` (compile neovim + download go) and runtime — keep this separation
- `main.tf` passes proxy build args to Docker; any new build args must be wired through both Terraform variables and Dockerfile ARGs
- The `coder` user's shell is fish; startup_script in `main.tf` uses fish syntax (`if not test`)
- `glibc-langpack-en` provides precompiled locales — do not use `localedef` (charmap source files are absent in Rocky 9 minimal)

### Testing Requirements
- Build image: `docker build --progress=plain -t coder-rocky-dev .`
- Verify locale: `docker run --rm --entrypoint="" coder-rocky-dev /bin/sh -c "locale -a | grep en_US"`
- Validate Terraform: `terraform validate`

### Common Patterns
- Mirror configuration follows the pattern: disable metalist/mirrorlist, set baseurl to USTC mirror
- Docker layer cleanup: `dnf -y clean all && rm -rf /var/cache/dnf` at end of each RUN
- Health check uses `pgrep fish` since fish is the entrypoint

## Dependencies

### External
- Rocky Linux 9 — base image
- Coder provider (`coder/coder`) — workspace orchestration
- Docker provider (`kreuzwerker/docker`) — container management
- USTC mirrors — package/registry acceleration for CN users

<!-- MANUAL: -->
