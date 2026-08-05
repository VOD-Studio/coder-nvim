#!/bin/sh
# xfy-nvim entrypoint — LinuxServer.io 模式：
# 镜像以 root 启动，动态调整 coder 用户 UID/GID 匹配宿主，
# 首次运行时把 seed 拷贝到挂载点，最后 exec gosu coder 切非特权用户。
# exec gosu 保证 nvim 拿到 PID 1 并正确接收 SIGINT/SIGTERM。
set -e

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"

if [ "$(id -u)" = "0" ]; then
  # 调整 coder 用户/组的 UID/GID 匹配宿主（-o 允许非唯一，usermod 接受数字 GID）
  groupmod -o -g "$HOST_GID" coder >/dev/null 2>&1 || true
  usermod -o -u "$HOST_UID" -g "$HOST_GID" -d /home/coder -s /bin/sh coder >/dev/null 2>&1 || true
  # Docker bind-mount 自动创建挂载点的父目录（如 .config/）时 owner 为 root，
  # 这会导致 tree-sitter 等工具无法在 ~/.config/tree-sitter/ 下创建配置。
  # 递归 chown 整个 home 目录，确保所有 XDG 父目录可写。
  chown -R "$HOST_UID:$HOST_GID" /home/coder 2>/dev/null || true

  # 首次运行：宿主挂载目录为空时从 seed 拷贝
  # seed/config → ~/.config/nvim（init.lua 入口）
  # seed/data   → ~/.local/share/nvim（vim.pack 下载的插件 + lock 文件）
  for pair in \
    "/opt/xfy-nvim/seed/config:/home/coder/.config/nvim" \
    "/opt/xfy-nvim/seed/data:/home/coder/.local/share/nvim"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    if [ -d "$src" ] && [ -z "$(ls -A "$dst" 2>/dev/null)" ]; then
      mkdir -p "$dst"
      cp -a "$src/." "$dst/"
      chown -R "$HOST_UID:$HOST_GID" "$dst"
    fi
  done

  # 切到非特权用户执行 CMD
  exec gosu coder "$@"
fi

# 非 root 启动（用户显式 docker run --user）直接 exec
exec "$@"
