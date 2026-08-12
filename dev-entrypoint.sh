#!/bin/bash
# Dev container entrypoint: 启动 sshd 作为 PID 1，容器职责是常驻 + 提供 SSH 会话。
# 实际开发在 ssh 进来后的交互 fish 会话里进行。
set -euo pipefail

SSHD_PORT="${SSHD_PORT:-29888}"
echo "[dev-entrypoint] booting; sshd will listen on 0.0.0.0:${SSHD_PORT}"

# 1. 缺失则生成 SSH host keys（首次启动 / 命名卷为空时）
ssh-keygen -A >/dev/null

# 2. sshd privilege separation 目录
mkdir -p /run/sshd

# 3. Docker socket 权限修复（镜像自带脚本，仅在挂载了 sock 时生效）
if [ -S /var/run/docker.sock ] && [ -x /usr/local/bin/fix-docker-sock.sh ]; then
    /usr/local/bin/fix-docker-sock.sh || true
fi

# 4. 注入宿主公钥为 coder 的 authorized_keys
#    幂等：缺失或与宿主公钥不一致时覆盖
if [ -f /mnt/host-pubkey ]; then
    install -d -m 700 -o coder -g coder /home/coder/.ssh
    if [ ! -f /home/coder/.ssh/authorized_keys ] || \
       ! cmp -s /mnt/host-pubkey /home/coder/.ssh/authorized_keys; then
        install -m 600 -o coder -g coder /mnt/host-pubkey /home/coder/.ssh/authorized_keys
        echo "[dev-entrypoint] authorized_keys refreshed"
    fi
else
    echo "[dev-entrypoint] WARNING: /mnt/host-pubkey 未挂载，SSH 登录将失败" >&2
fi

# 5. 前台启动 sshd（PID 1）。-D 不 fork，-e 日志到 stderr
exec /usr/sbin/sshd -D -e \
    -p "${SSHD_PORT}" \
    -o PasswordAuthentication=no \
    -o PubkeyAuthentication=yes \
    -o PermitRootLogin=no \
    -o AllowUsers=coder
