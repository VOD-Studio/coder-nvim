# xfy-nvim — Containerized Neovim 0.12 as a local editor
# Reuses coder-nvim patterns (USTC mirrors, multi-arch, glibc-langpack-en,
# DefectingCat/nvim 0.12 config) but strips ALL dev toolchains.
# Goal: `xv file.rs` opens the file inside this container with host UID/GID.

# ============ Builder 阶段 ============
FROM rockylinux:9 AS builder

# 代理设置 - 构建时从宿主机继承
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG TARGETARCH

ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy}

# 配置 USTC 镜像源
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf makecache

# 安装最小构建依赖（仅用于下载/解压 nvim tarball 和 git clone 配置）
RUN dnf -y install epel-release && \
    dnf -y config-manager --set-enabled crb && \
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && dnf makecache \
    && dnf -y --allowerasing install git curl unzip tar

# 下载 Neovim 预编译二进制（适配系统架构）
RUN ARCH="${TARGETARCH:-amd64}" \
    && case "${ARCH}" in \
        "amd64") NVIM_ARCH="x86_64" ;; \
        "arm64") NVIM_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac \
    && curl --retry 5 --retry-delay 3 -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" -o /tmp/nvim.tar.gz \
    && tar -xzf /tmp/nvim.tar.gz -C /tmp \
    && cp "/tmp/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim \
    && cp -r "/tmp/nvim-linux-${NVIM_ARCH}/lib/nvim" /usr/local/lib/nvim \
    && cp -r "/tmp/nvim-linux-${NVIM_ARCH}/share/nvim" /usr/local/share/nvim \
    && rm -rf "/tmp/nvim-linux-${NVIM_ARCH}" /tmp/nvim.tar.gz
# （tree-sitter CLI 在 runtime 阶段从 prebuilt binary 安装，不在 builder 编译）

# 克隆 nvim 配置仓库（0.12 分支）
RUN git clone --depth 1 -b 0.12 https://github.com/DefectingCat/nvim /tmp/nvim-config

# 容器内 OSC 52 剪贴板覆盖（after/plugin 在启动序列最末加载，覆盖自带剪贴板配置）
COPY osc52.lua /tmp/nvim-config/after/plugin/osc52.lua

# 预装插件：pack.lua 的 vim.pack.add({...}, {load=false}) 在启动时同步下载所有插件
# 到 stdpath("data")/site/pack/core/opt/。load=false 只下载不加载（懒加载由 lazy.lua 触发）。
# 关键：必须通过 $HOME/.config/nvim/ 默认 XDG 路径让 nvim 自动发现配置（rtp 才会包含 config dir），
# 用 -u init.lua 不会把 config dir 加入 rtp，require('options') 等会失败。
# 用 symlink 避免重复拷贝；vim.pack.add 的 async timeout 在所有插件下载完成后才触发，无害。
RUN mkdir -p /tmp/nvim-home/.config \
             /tmp/nvim-home/.local/share/nvim \
             /tmp/nvim-home/.local/state/nvim \
             /tmp/nvim-home/.cache/nvim \
    && ln -sf /tmp/nvim-config /tmp/nvim-home/.config/nvim \
    && HOME=/tmp/nvim-home nvim --headless -c 'qa!' || true
# 清理 .git 目录：macOS Docker 挂载（VirtioFS）拒绝 git pack 文件的 chmod，
# cp -a 会因 mode 设置失败而中止。strip .git 后 seed 拷贝干净无错。
# vim.pack.add() 在 plugin dir 存在时不会因缺少 .git 报错（插件代码在工作树，可直接加载）；
# 代价是 :PackUpdate 在宿主侧无法增量更新（需重建镜像或 rm -rf ~/.xfy-nvim/data 重新 seed）。
RUN rm -rf /tmp/nvim-config/.git \
    && find /tmp/nvim-home/.local/share/nvim/site/pack -type d -name .git -prune -exec rm -rf {} +

# ============ Runtime 阶段 ============
FROM rockylinux:9

# 代理设置
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG TARGETARCH

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# 配置 USTC 镜像源
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf makecache

# 安装最小编辑依赖（不装 vim/nano/python3/tmux/fish/sudo/openssh 等生活环境包）
RUN dnf -y install epel-release && \
    dnf -y config-manager --set-enabled crb && \
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && dnf makecache \
    && dnf -y --allowerasing install \
       git unzip tar gzip \
       ripgrep fd-find \
       gcc make \
       glibc-langpack-en \
       procps-ng which \
    && dnf -y clean all \
    && rm -rf /var/cache/dnf /var/lib/dnf /var/log/dnf* \
    && rm -rf /usr/share/{man,doc,info,licenses} /usr/share/locale/*/LC_MESSAGES 2>/dev/null; :

# 下载 gosu（多架构，用于 entrypoint 动态 UID/GID 切换；与第三方 CLI 下载模式一致）
RUN ARCH="${TARGETARCH:-amd64}" \
    && case "${ARCH}" in \
        "amd64") GOSU_ARCH="amd64" ;; \
        "arm64") GOSU_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac \
    && GOSU_VER=$(curl -fsSLI --retry 3 -A "Mozilla/5.0" https://github.com/tianon/gosu/releases/latest | grep -i '^location:' | tail -n 1 | sed 's@.*tag/@@' | tr -d '\r\n') \
    && curl --retry 3 -fsSL "https://github.com/tianon/gosu/releases/download/${GOSU_VER}/gosu-${GOSU_ARCH}" -o /usr/local/bin/gosu \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true
# 下载 tree-sitter CLI（多架构）
# nvim-treesitter main 分支用外部 tree-sitter build 编译 parser，缺少此二进制会报 ENOENT: 'tree-sitter'。
# pin 到 v0.25.3：0.26.x 的 prebuilt binary 需要 GLIBC_2.35+，Rocky 9 只有 2.34。
# v0.25.3 只需 GLIBC_2.29，兼容 Rocky 9。0.26.x 需从源码编译 CLI（Rust），不值得引入 Rust 工具链。
RUN ARCH="${TARGETARCH:-amd64}" \
    && case "${ARCH}" in \
        "amd64") TS_ARCH="x64" ;; \
        "arm64") TS_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac \
    && curl --retry 3 -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/v0.25.3/tree-sitter-linux-${TS_ARCH}.gz" -o /tmp/tree-sitter.gz \
    && gunzip -f /tmp/tree-sitter.gz \
    && chmod +x /tmp/tree-sitter \
    && mv /tmp/tree-sitter /usr/local/bin/tree-sitter \
    && tree-sitter --version
# tree-sitter CLI 用 ${TRIPLE}-gcc 编译 parser（如 aarch64-linux-gnu-gcc），
# 但 Rocky 9 原生 gcc 不带 triple 前缀。创建 symlink 让 tree-sitter 能找到编译器。
RUN case "${TARGETARCH:-amd64}" in \
        "amd64") ln -sf "$(which gcc)" /usr/local/bin/x86_64-linux-gnu-gcc ;; \
        "arm64") ln -sf "$(which gcc)" /usr/local/bin/aarch64-linux-gnu-gcc ;; \
    esac

# 从 builder 复制 Neovim 二进制/lib/share
COPY --from=builder /usr/local/bin/nvim /usr/local/bin/nvim
COPY --from=builder /usr/local/lib/nvim /usr/local/lib/nvim
COPY --from=builder /usr/local/share/nvim /usr/local/share/nvim

# 从 builder 复制 seed（只存一份在 /opt/xfy-nvim/seed/，entrypoint 在首次运行时拷贝到挂载点）
COPY --from=builder /tmp/nvim-config /opt/xfy-nvim/seed/config
COPY --from=builder /tmp/nvim-home/.local/share/nvim /opt/xfy-nvim/seed/data

# 创建 coder 用户（不装 fish、不写 sudoers；entrypoint 动态调 UID/GID）
RUN useradd -m -s /bin/sh coder

# 安装 entrypoint
COPY entrypoint.sh /usr/local/bin/xfy-entrypoint.sh
RUN chmod +x /usr/local/bin/xfy-entrypoint.sh

WORKDIR /workdir
# 镜像以 root 启动（不写 USER coder），entrypoint 完成 UID/GID 调整 + seed 拷贝后 exec gosu coder
ENTRYPOINT ["/usr/local/bin/xfy-entrypoint.sh"]
CMD ["nvim"]
