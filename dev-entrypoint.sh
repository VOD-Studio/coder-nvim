#!/bin/bash
# Dev container entrypoint: 启动 sshd 作为 PID 1，容器职责是常驻 + 提供 SSH 会话。
# 实际开发在 ssh 进来后的交互 fish 会话里进行。
set -euo pipefail

SSHD_PORT="${SSHD_PORT:-29888}"
echo "[dev-entrypoint] booting; sshd will listen on 0.0.0.0:${SSHD_PORT}"

# 1. 确保 SSH Host Keys 持久化（存储在已持久化的 /home/coder 中，避免容器重建后 host key 变更）
HOST_KEYS_DIR="/home/coder/.ssh_host_keys"
mkdir -p "${HOST_KEYS_DIR}"
chmod 700 "${HOST_KEYS_DIR}"

if [ ! -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key" ]; then
    echo "[dev-entrypoint] generating persistent SSH host keys in ${HOST_KEYS_DIR}..."
    ssh-keygen -q -t ed25519 -N '' -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key"
    ssh-keygen -q -t rsa -b 4096 -N '' -f "${HOST_KEYS_DIR}/ssh_host_rsa_key"
    ssh-keygen -q -t ecdsa -N '' -f "${HOST_KEYS_DIR}/ssh_host_ecdsa_key"
fi

cp "${HOST_KEYS_DIR}"/ssh_host_* /etc/ssh/
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

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

# 5. 注入宿主 ~/.ssh/config（只读挂载在 /mnt/host-ssh-config）
#    幂等：缺失或与宿主不一致时覆盖；属主 coder、权限 0644
#    （ssh 要求 config 属主为当前用户或 root，且不可被 group/other 写入）
if [ -f /mnt/host-ssh-config ]; then
    if [ ! -f /home/coder/.ssh/config ] || \
       ! cmp -s /mnt/host-ssh-config /home/coder/.ssh/config; then
        install -m 644 -o coder -g coder /mnt/host-ssh-config /home/coder/.ssh/config
        echo "[dev-entrypoint] ~/.ssh/config synced from host"
    fi
else
    echo "[dev-entrypoint] /mnt/host-ssh-config 未挂载，跳过 ssh config 注入" >&2
fi

# 6. 注入宿主私钥（只读挂载在 /mnt/host-ssh-key）
#    幂等：缺失或与宿主不一致时覆盖；属主 coder、权限 0600
#    （ssh 对私钥极严格：仅属主可读，否则报 UNPROTECTED PRIVATE KEY FILE 并拒绝使用）
if [ -f /mnt/host-ssh-key ]; then
    if [ ! -f /home/coder/.ssh/id_ed25519 ] || \
       ! cmp -s /mnt/host-ssh-key /home/coder/.ssh/id_ed25519; then
        install -m 600 -o coder -g coder /mnt/host-ssh-key /home/coder/.ssh/id_ed25519
        echo "[dev-entrypoint] ~/.ssh/id_ed25519 synced from host"
    fi
else
    echo "[dev-entrypoint] /mnt/host-ssh-key 未挂载，跳过私钥注入" >&2
fi

# 7. 前台启动 sshd（PID 1）。-D 不 fork，-e 日志到 stderr
exec /usr/sbin/sshd -D -e \
    -p "${SSHD_PORT}" \
    -o PasswordAuthentication=no \
    -o PubkeyAuthentication=yes \
    -o PermitRootLogin=no \
    -o AllowUsers=coder
