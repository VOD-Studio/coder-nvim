FROM rockylinux:9 AS builder

# 代理设置 - 构建时从宿主机继承
ARG http_proxy
ARG https_proxy
ARG no_proxy

ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy}

# 配置 USTC 镜像源
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf makecache

# 安装编译依赖
RUN dnf -y install epel-release && \
    dnf -y config-manager --set-enabled crb && \
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && dnf makecache \
    && dnf -y --allowerasing install git curl unzip

# 下载并解压 Go（自动获取最新稳定版）
RUN GO_VER=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1) \
    && curl --retry 3 --retry-delay 5 -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

# 克隆 dotfiles 仓库
RUN git clone --depth 1 https://github.com/DefectingCat/dotfiles.git /tmp/dotfiles

# 克隆 nvim 配置仓库
RUN git clone --depth 1 -b 0.12 https://github.com/DefectingCat/nvim /tmp/nvim-config

# 下载 Go 工具
RUN GOBIN=/usr/local/bin go install github.com/charmbracelet/crush@latest
RUN curl --retry 3 --retry-delay 5 -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz -C /usr/local/bin \
    && curl --retry 3 --retry-delay 5 -fsSL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz -C /usr/local/bin \
    && LSD_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" https://github.com/lsd-rs/lsd/releases/latest | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
    && curl --retry 3 --retry-delay 5 -fsSL "https://github.com/lsd-rs/lsd/releases/latest/download/lsd-v${LSD_VER}-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin --strip-components=1 "lsd-v${LSD_VER}-x86_64-unknown-linux-gnu/lsd" \
    && BAT_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" https://github.com/sharkdp/bat/releases/latest | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
    && curl --retry 3 --retry-delay 5 -fsSL "https://github.com/sharkdp/bat/releases/latest/download/bat-v${BAT_VER}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/bat.tar.gz \
    && tar -xzf /tmp/bat.tar.gz -C /tmp \
    && cp /tmp/bat-v${BAT_VER}-x86_64-unknown-linux-gnu/bat /usr/local/bin/ \
    && rm -rf /tmp/bat* \
    && LG_VER=$(curl -fsSLI --retry 3 --retry-delay 5 -A "Mozilla/5.0" https://github.com/jesseduffield/lazygit/releases/latest | grep -i '^location:' | tail -n 1 | sed 's/.*\/tag\/v\?//' | tr -d '\r\n') \
    && curl --retry 3 --retry-delay 5 -fsSL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin lazygit

# 下载 Neovim 预编译二进制
RUN curl --retry 5 --retry-delay 3 -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" -o /tmp/nvim.tar.gz \
    && tar -xzf /tmp/nvim.tar.gz -C /tmp \
    && cp /tmp/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
    && cp -r /tmp/nvim-linux-x86_64/lib/nvim /usr/local/lib/nvim \
    && cp -r /tmp/nvim-linux-x86_64/share/nvim /usr/local/share/nvim \
    && rm -rf /tmp/nvim-linux-x86_64 /tmp/nvim.tar.gz

# 下载 fnm
RUN curl --retry 5 --retry-delay 3 --http1.1 -fsSL https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip -o /tmp/fnm.zip \
    && mkdir -p /usr/local/fnm \
    && unzip -o /tmp/fnm.zip -d /usr/local/fnm \
    && rm /tmp/fnm.zip

# ============ 运行阶段 ============
FROM rockylinux:9

# 代理设置
ARG http_proxy
ARG https_proxy
ARG no_proxy

# 设置环境变量
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    no_proxy=${no_proxy}

# 配置 USTC 镜像源
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
        -i.bak \
        /etc/yum.repos.d/rocky.repo \
        /etc/yum.repos.d/rocky-extras.repo \
    && dnf makecache

# 安装运行时依赖
RUN dnf -y install epel-release && \
    dnf -y config-manager --set-enabled crb && \
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=https\?://download.fedoraproject.org/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -e 's|^#baseurl=https\?://download.example/pub/epel/|baseurl=https://mirrors.ustc.edu.cn/epel/|g' \
        -i.bak /etc/yum.repos.d/epel{,-testing}.repo \
    && dnf makecache \
    && dnf -y --allowerasing install \
    wget git vim nano unzip zip tar gzip bzip2 xz make \
    sudo passwd openssh-server procps-ng htop net-tools bind-utils lsof strace \
    tmux screen fish util-linux-user \
    python3 python3-pip python3-devel \
    ripgrep fd-find fastfetch curl glibc-langpack-en gcc clang-devel \
    && dnf -y clean all \
    && rm -rf /var/cache/dnf /var/lib/dnf /var/log/dnf* \
    && rm -rf /usr/share/{man,doc,info,licenses} /usr/share/locale/*/LC_MESSAGES 2>/dev/null; : \
    && pip3 cache purge 2>/dev/null; :

# 安装 Docker CLI
RUN dnf -y install dnf-utils && \
    dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo && \
    sed -i 's|https://download.docker.com|https://mirrors.aliyun.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo && \
    dnf makecache && \
    dnf -y install docker-ce-cli && \
    dnf -y clean all && \
    rm -rf /var/cache/dnf

# 从构建阶段复制二进制工具
COPY --from=builder /usr/local/bin/starship /usr/local/bin/eza /usr/local/bin/lsd /usr/local/bin/bat /usr/local/bin/lazygit /usr/local/bin/crush /usr/local/bin/

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
RUN echo 'set -gx PATH /usr/local/bin $PATH /usr/local/go/bin /usr/local/fnm' > /home/coder/.config/fish/conf.d/path.fish \
    && echo 'set -gx RUSTUP_HOME /home/coder/.rustup' > /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx CARGO_HOME /home/coder/.cargo' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx RUSTUP_DIST_SERVER https://mirrors.ustc.edu.cn/rust-static' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx RUSTUP_UPDATE_ROOT https://mirrors.ustc.edu.cn/rust-static/rustup' >> /home/coder/.config/fish/conf.d/rustup.fish \
    && echo 'set -gx PATH $PATH /home/coder/.cargo/bin' >> /home/coder/.config/fish/conf.d/rustup.fish

# 安装开发工具并设置权限
RUN mkdir -p /home/coder/.local/share/fnm \
    /home/coder/.rustup \
    /home/coder/.cargo \
    && FNM_DIR=/home/coder/.local/share/fnm FNM_NODE_DIST_MIRROR=https://npmmirror.com/mirrors/node fnm install 'lts/*' \
    # 全局安装 claude-code
    && FNM_DIR=/home/coder/.local/share/fnm FNM_NODE_DIST_MIRROR=https://npmmirror.com/mirrors/node fnm exec --using=lts/latest -- npm i -g @anthropic-ai/claude-code \
    && FNM_DIR=/home/coder/.local/share/fnm fnm exec --using=lts/latest -- npm cache clean --force \
    && RUSTUP_HOME=/home/coder/.rustup CARGO_HOME=/home/coder/.cargo RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | RUSTUP_HOME=/home/coder/.rustup CARGO_HOME=/home/coder/.cargo RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup sh -s -- -y --no-modify-path \
    && PATH=/home/coder/.cargo/bin:$PATH /home/coder/.cargo/bin/rustup default stable \
    && PATH=/home/coder/.cargo/bin:$PATH RUSTUP_HOME=/home/coder/.rustup CARGO_HOME=/home/coder/.cargo /home/coder/.cargo/bin/cargo install --root /usr/local tree-sitter-cli \
    && printf '[source.crates-io]\nreplace-with = "ustc"\n\n[source.ustc]\nregistry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"\n\n[registries.ustc]\nindex = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"\n' > /home/coder/.cargo/config.toml \
    && chown -R coder:coder /home/coder/.config /home/coder/.local /home/coder/.rustup /home/coder/.cargo \
    && rm -rf /tmp/* /home/coder/.cache/pip /root/.cache/pip 2>/dev/null; :

# 安装 nvim 插件
RUN mkdir -p /home/coder/.local/share/nvim \
    /home/coder/.local/state/nvim \
    /home/coder/.cache/nvim \
    && chown -R coder:coder /home/coder/.config /home/coder/.local /home/coder/.cache \
    && su - coder -c "nvim --headless -c 'PackUpdate' -c 'qa!'" || true \
    && rm -rf /tmp/* /root/.npm /home/coder/.npm 2>/dev/null; :

WORKDIR /home/coder
USER coder
ENTRYPOINT ["fish"]
