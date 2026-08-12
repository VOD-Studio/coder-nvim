FROM rockylinux:9 AS builder

# 代理设置 - 构建时从宿主机继承
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG TARGETARCH
ARG GH_PROXY="https://ghfast.top/"
ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy}

# 配置 USTC 镜像源并安装编译依赖
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf -y install epel-release \
    && dnf -y config-manager --set-enabled crb \
    && sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && dnf makecache \
    && dnf -y --allowerasing install git curl unzip gzip tar

# 并行下载 Go、dotfiles、nvim-config、tree-sitter 与各种 CLI 工具
RUN ARCH="${TARGETARCH:-amd64}" \
    && case "${ARCH}" in \
        "amd64") \
            GO_ARCH="amd64" \
            RUST_TARGET="x86_64-unknown-linux-gnu" \
            STARSHIP_TARGET="x86_64-unknown-linux-gnu" \
            LG_ARCH="Linux_x86_64" \
            NVIM_ARCH="x86_64" \
            FNM_FILE="fnm-linux.zip" \
            BUN_ARCH="x64" \
            TS_ARCH="x64" ;; \
        "arm64") \
            GO_ARCH="arm64" \
            RUST_TARGET="aarch64-unknown-linux-gnu" \
            STARSHIP_TARGET="aarch64-unknown-linux-musl" \
            LG_ARCH="Linux_arm64" \
            NVIM_ARCH="arm64" \
            FNM_FILE="fnm-arm64.zip" \
            BUN_ARCH="aarch64" \
            TS_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac \
    # 1. Go
    && ( GO_VER=$(curl -fsSL 'https://golang.google.cn/VERSION?m=text' | head -1) \
         && mkdir -p /tmp/go_tmp \
         && curl --retry 3 --retry-delay 5 -fsSL "https://golang.google.cn/dl/${GO_VER}.linux-${GO_ARCH}.tar.gz" -o /tmp/go_tmp/go.tar.gz \
         && tar -C /usr/local -xzf /tmp/go_tmp/go.tar.gz \
         && rm -rf /tmp/go_tmp ) & \
    # 2. dotfiles
    ( git clone --depth 1 "${GH_PROXY}https://github.com/DefectingCat/dotfiles.git" /tmp/dotfiles ) & \
    # 3. nvim-config
    ( git clone --depth 1 -b 0.12 "${GH_PROXY}https://github.com/DefectingCat/nvim" /tmp/nvim-config ) & \
    # 4. Starship
    ( curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/starship/starship/releases/latest/download/starship-${STARSHIP_TARGET}.tar.gz" | tar -xz -C /usr/local/bin ) & \
    # 5. eza
    ( curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/eza-community/eza/releases/latest/download/eza_${RUST_TARGET}.tar.gz" | tar -xz -C /usr/local/bin ) & \
    # 6. lsd
    ( LSD_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" "${GH_PROXY}https://github.com/lsd-rs/lsd/releases/latest" | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
         && curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/lsd-rs/lsd/releases/latest/download/lsd-v${LSD_VER}-${RUST_TARGET}.tar.gz" | tar -xz -C /usr/local/bin --strip-components=1 "lsd-v${LSD_VER}-${RUST_TARGET}/lsd" ) & \
    # 7. bat
    ( BAT_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" "${GH_PROXY}https://github.com/sharkdp/bat/releases/latest" | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
         && mkdir -p /tmp/bat_tmp \
         && curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/sharkdp/bat/releases/latest/download/bat-v${BAT_VER}-${RUST_TARGET}.tar.gz" -o /tmp/bat_tmp/bat.tar.gz \
         && tar -xzf /tmp/bat_tmp/bat.tar.gz -C /tmp/bat_tmp \
         && cp "/tmp/bat_tmp/bat-v${BAT_VER}-${RUST_TARGET}/bat" /usr/local/bin/ \
         && rm -rf /tmp/bat_tmp ) & \
    # 8. lazygit
    ( LG_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" "${GH_PROXY}https://github.com/jesseduffield/lazygit/releases/latest" | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
         && curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_${LG_ARCH}.tar.gz" | tar -xz -C /usr/local/bin lazygit ) & \
    # 9. Neovim
    ( mkdir -p /tmp/nvim_tmp \
         && curl --retry 5 --retry-delay 3 -fsSL "${GH_PROXY}https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" -o /tmp/nvim_tmp/nvim.tar.gz \
         && tar -xzf /tmp/nvim_tmp/nvim.tar.gz -C /tmp/nvim_tmp \
         && cp "/tmp/nvim_tmp/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim \
         && cp -r "/tmp/nvim_tmp/nvim-linux-${NVIM_ARCH}/lib/nvim" /usr/local/lib/nvim \
         && cp -r "/tmp/nvim_tmp/nvim-linux-${NVIM_ARCH}/share/nvim" /usr/local/share/nvim \
         && rm -rf /tmp/nvim_tmp ) & \
    # 10. fnm
    ( mkdir -p /usr/local/fnm /tmp/fnm_tmp \
         && curl --retry 5 --retry-delay 3 --http1.1 -fsSL "${GH_PROXY}https://github.com/Schniz/fnm/releases/latest/download/${FNM_FILE}" -o /tmp/fnm_tmp/fnm.zip \
         && unzip -o /tmp/fnm_tmp/fnm.zip -d /usr/local/fnm \
         && rm -rf /tmp/fnm_tmp ) & \
    # 11. Bun
    ( mkdir -p /tmp/bun_tmp \
         && curl --retry 5 --retry-delay 3 -fsSL "${GH_PROXY}https://github.com/oven-sh/bun/releases/latest/download/bun-linux-${BUN_ARCH}.zip" -o /tmp/bun_tmp/bun.zip \
         && unzip -o /tmp/bun_tmp/bun.zip -d /tmp/bun_tmp \
         && mv "/tmp/bun_tmp/bun-linux-${BUN_ARCH}/bun" /usr/local/bin/bun \
         && chmod +x /usr/local/bin/bun \
         && rm -rf /tmp/bun_tmp ) & \
    # 12. tree-sitter CLI (预编译二进制 v0.25.3，避免源码编译长耗时)
    ( curl --retry 3 --retry-delay 5 -fsSL "${GH_PROXY}https://github.com/tree-sitter/tree-sitter/releases/download/v0.25.3/tree-sitter-linux-${TS_ARCH}.gz" | gzip -d > /usr/local/bin/tree-sitter \
         && chmod +x /usr/local/bin/tree-sitter ) & \
    # 等待并发任务全部结束
    wait

ENV PATH=$PATH:/usr/local/go/bin

# ============ 运行阶段 ============
FROM rockylinux:9

# 代理设置
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG TARGETARCH
ARG GH_PROXY="https://ghfast.top/"
# 设置环境变量
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    no_proxy=${no_proxy}

# 配置镜像源并合并一键安装所有 RPM 运行时依赖包（启用 BuildKit DNF 缓存挂载）
RUN --mount=type=cache,target=/var/cache/dnf \
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf -y install epel-release dnf-utils \
    && dnf -y config-manager --set-enabled crb \
    && dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo \
    && sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && sed -i 's|https://download.docker.com|https://mirrors.aliyun.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo \
    && dnf makecache \
    && dnf -y --allowerasing install \
    wget git vim nano unzip zip tar gzip bzip2 xz make \
    sudo passwd openssh-server procps-ng htop net-tools bind-utils lsof strace \
    tmux screen fish util-linux-user \
    python3 python3-pip python3-devel \
    ripgrep fd-find fastfetch curl glibc-langpack-en gcc clang-devel \
    docker-ce-cli \
    && dnf -y clean all \
    && rm -rf /var/cache/dnf /var/lib/dnf /var/log/dnf* \
    && rm -rf /usr/share/{man,doc,info,licenses} /usr/share/locale/*/LC_MESSAGES 2>/dev/null; : \
    && pip3 cache purge 2>/dev/null; :

# 从构建阶段复制二进制工具
COPY --from=builder /usr/local/bin/starship /usr/local/bin/eza /usr/local/bin/lsd /usr/local/bin/bat /usr/local/bin/lazygit /usr/local/bin/bun /usr/local/bin/tree-sitter /usr/local/bin/

# 从构建阶段复制 Neovim
COPY --from=builder /usr/local/bin/nvim /usr/local/bin/
COPY --from=builder /usr/local/lib/nvim /usr/local/lib/nvim
COPY --from=builder /usr/local/share/nvim /usr/local/share/nvim

# 从构建阶段复制 Go
COPY --from=builder /usr/local/go /usr/local/go

ENV PATH=$PATH:/usr/local/go/bin

# 从构建阶段复制 fnm
COPY --from=builder /usr/local/fnm /usr/local/fnm
RUN ln -s /usr/local/fnm/fnm /usr/local/bin/fnm

# 创建 coder 用户
RUN useradd -m -s /usr/bin/fish coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder

# 创建 docker socket 权限修复脚本
RUN echo '#!/bin/sh' > /usr/local/bin/fix-docker-sock.sh && \
    echo 'if [ -S /var/run/docker.sock ]; then' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '  DOCKER_GID=$(stat -c "%g" /var/run/docker.sock 2>/dev/null)' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '  if [ -n "$DOCKER_GID" ]; then' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    CURRENT_DOCKER_GID=$(grep "^docker:" /etc/group | cut -d: -f3)' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    if [ -z "$CURRENT_DOCKER_GID" ]; then' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '      groupadd -g "$DOCKER_GID" docker' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    elif [ "$CURRENT_DOCKER_GID" != "$DOCKER_GID" ]; then' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '      groupmod -g "$DOCKER_GID" docker 2>/dev/null || true' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    fi' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    usermod -aG docker coder 2>/dev/null || true' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '    chmod 660 /var/run/docker.sock 2>/dev/null || true' >> /usr/local/bin/fix-docker-sock.sh && \
    echo '  fi' >> /usr/local/bin/fix-docker-sock.sh && \
    echo 'fi' >> /usr/local/bin/fix-docker-sock.sh && \
    chmod +x /usr/local/bin/fix-docker-sock.sh

# 创建 docker wrapper 脚本（如果权限不够则自动使用 sudo）
RUN mkdir -p /home/coder/.config/fish/conf.d && \
    echo 'IyEvYmluL3NoCmlmIFsgLXcgL3Zhci9ydW4vZG9ja2VyLnNvY2sgXTsgdGhlbgogIGV4ZWMgZG9ja2VyICIkQCIKZmkKZXhlYyBzdWRvIGRvY2tlciAiJEAiCg==' | base64 -d > /usr/local/bin/docker-wrapper && \
    chmod +x /usr/local/bin/docker-wrapper && \
    echo 'alias docker docker-wrapper' > /home/coder/.config/fish/conf.d/docker.fish && \
    chown -R coder:coder /home/coder/.config/fish/conf.d/docker.fish

# 从构建阶段复制 fish 配置
COPY --from=builder /tmp/dotfiles/fish /home/coder/.config/fish

# 从构建阶段复制 tmux 配置
RUN mkdir -p /home/coder/.config/tmux
COPY --from=builder /tmp/dotfiles/tmux.conf /home/coder/.config/tmux/tmux.conf
RUN ln -sf /home/coder/.config/tmux/tmux.conf /home/coder/.tmux.conf

# 从构建阶段复制 nvim 配置
COPY --from=builder /tmp/nvim-config /home/coder/.config/nvim

# 添加 Go/fnm/rustup 环境配置
RUN echo 'set -gx PATH /usr/local/bin $PATH /usr/local/go/bin /usr/local/fnm /home/coder/.bun/bin' > /home/coder/.config/fish/conf.d/path.fish \
    && echo 'set -gx RUSTUP_HOME /home/coder/.rustup' > /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx CARGO_HOME /home/coder/.cargo' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx RUSTUP_DIST_SERVER https://mirrors.ustc.edu.cn/rust-static' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx RUSTUP_UPDATE_ROOT https://mirrors.ustc.edu.cn/rust-static/rustup' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx PATH $PATH /home/coder/.cargo/bin' >> /home/coder/.config/fish/conf.d/rustup.fish

# 并行安装应用环境 (Bun 全局包 / fnm Node & claude-code / Rustup) 并设置权限
RUN mkdir -p /home/coder/.local/share/fnm \
    /home/coder/.rustup \
    /home/coder/.cargo \
    # 1. Bun 镜像源与 omp
    && ( printf '[install]\nregistry = "https://registry.npmmirror.com"\n' > /root/.bunfig.toml \
         && cp /root/.bunfig.toml /home/coder/.bunfig.toml \
         && BUN_INSTALL=/usr/local bun add -g @oh-my-pi/pi-coding-agent ) & \
    # 2. fnm Node LTS & claude-code
    ( FNM_DIR=/home/coder/.local/share/fnm FNM_NODE_DIST_MIRROR=https://npmmirror.com/mirrors/node fnm install 'lts/*' \
         && FNM_DIR=/home/coder/.local/share/fnm FNM_NODE_DIST_MIRROR=https://npmmirror.com/mirrors/node fnm exec --using=lts/latest -- npm i -g @anthropic-ai/claude-code \
         && FNM_DIR=/home/coder/.local/share/fnm fnm exec --using=lts/latest -- npm cache clean --force ) & \
    # 3. Rustup 工具链与 crates 镜像源配置
    ( case "$(uname -m)" in \
            "x86_64"|"amd64") RUST_TARGET="x86_64-unknown-linux-gnu" ;; \
            "aarch64"|"arm64") RUST_TARGET="aarch64-unknown-linux-gnu" ;; \
            *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
         esac \
         && curl --retry 3 --retry-delay 5 -fsSL "https://mirrors.ustc.edu.cn/rust-static/rustup/dist/${RUST_TARGET}/rustup-init" -o /tmp/rustup-init \
         && chmod +x /tmp/rustup-init \
         && RUSTUP_HOME=/home/coder/.rustup CARGO_HOME=/home/coder/.cargo RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup /tmp/rustup-init -y --profile minimal --no-modify-path \
         && rm -f /tmp/rustup-init \
         && printf '[source.crates-io]\nreplace-with = "ustc"\n\n[source.ustc]\nregistry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"\n\n[registries.ustc]\nindex = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"\n' > /home/coder/.cargo/config.toml ) & \
    wait \
    && chown -R coder:coder /home/coder/.config /home/coder/.local /home/coder/.rustup /home/coder/.cargo /home/coder/.bunfig.toml \
    && rm -rf /tmp/* /home/coder/.cache/pip /root/.cache/pip 2>/dev/null; :

# 安装 nvim 插件
RUN mkdir -p /home/coder/.local/share/nvim \
    /home/coder/.local/state/nvim \
    /home/coder/.cache/nvim \
    && chown -R coder:coder /home/coder/.config /home/coder/.local /home/coder/.cache \
    && if [ -n "${GH_PROXY}" ]; then su - coder -c "git config --global url.\"${GH_PROXY}https://github.com/\".insteadOf \"https://github.com/\""; fi \
    && su - coder -c "nvim --headless -c 'PackUpdate' -c 'qa!'" || true

WORKDIR /home/coder
USER coder
ENTRYPOINT ["fish"]
