# =============================================================================
# Stage 1: Builder - Prepare all artifacts
# =============================================================================
FROM cgr.dev/chainguard/node:latest-dev@sha256:7137fadb43a7cee4a01495749973f3c8c44a1d02319d9beb543bdb21cb6e874e AS builder

USER root

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    git \
    jq \
    unzip \
    xz

# renovate: datasource=github-releases depName=version-fox/vfox
ARG VFOX_VERSION=1.0.11

# renovate: datasource=github-releases depName=zellij-org/zellij
ARG ZELLIJ_VERSION=0.44.3

# renovate: datasource=github-releases depName=jesseduffield/lazygit
ARG LAZYGIT_VERSION=0.63.0

# renovate: datasource=github-releases depName=fish-shell/fish-shell
ARG FISH_VERSION=4.8.0

# renovate: datasource=github-releases depName=ast-grep/ast-grep
ARG ASTGREP_VERSION=0.44.1

# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.206

# renovate: datasource=npm depName=typescript
ARG TYPESCRIPT_VERSION=6.0.3
# renovate: datasource=npm depName=ts-node
ARG TS_NODE_VERSION=10.9.2

# Download zellij, vfox, and claude binaries
ARG TARGETARCH
RUN mkdir -p /usr/local/bin && \
    ARCH=$(uname -m) && \
    LAZYGIT_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "arm64") && \
    FISH_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    AST_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C /usr/local/bin && \
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz" | tar -xz -C /usr/local/bin lazygit && \
    curl -fsSL "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${FISH_ARCH}.tar.xz" | tar -xJ -C /usr/local/bin && \
    curl -fsSL "https://github.com/ast-grep/ast-grep/releases/download/${ASTGREP_VERSION}/app-${AST_ARCH}-unknown-linux-gnu.zip" -o /tmp/ast-grep.zip && \
    unzip -o /tmp/ast-grep.zip ast-grep -d /usr/local/bin && \
    rm /tmp/ast-grep.zip && \
    curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash && \
    GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" && \
    PLATFORM="linux-$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64")" && \
    CHECKSUM=$(curl -fsSL "$GCS_BUCKET/$CLAUDE_CODE_VERSION/manifest.json" | jq -r ".platforms[\"$PLATFORM\"].checksum") && \
    curl -fsSL "$GCS_BUCKET/$CLAUDE_CODE_VERSION/$PLATFORM/claude" -o /usr/local/bin/claude && \
    ACTUAL=$(sha256sum /usr/local/bin/claude | cut -d' ' -f1) && \
    [ "$ACTUAL" = "$CHECKSUM" ] || { echo "Checksum verification failed"; exit 1; } && \
    chmod +x /usr/local/bin/claude

# Install global npm packages
RUN npm install -g \
    npm \
    typescript@${TYPESCRIPT_VERSION} \
    ts-node@${TS_NODE_VERSION} \
    @types/node \
    && npm cache clean --force

# =============================================================================
# Stage 2: Final - Runtime image
# =============================================================================
FROM ghcr.io/astral-sh/uv:python3.14-trixie-slim@sha256:b6e3a8825dfb232a6b962228f0b5cf98ee1d2b4263f62c2639f68887f4e634a2 AS final

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    coreutils \
    curl \
    wget \
    zsh \
    git \
    git-lfs \
    gnupg \
    xz-utils \
    unzip \
    jq \
    less \
    nodejs \
    openssh-client \
    ripgrep \
    fd-find \
    fzf \
    tree \
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    && apt-get purge -y --auto-remove \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
        /usr/share/doc/* \
        /usr/share/man/* \
        /usr/share/info/* \
        /usr/share/locale/* \
        /usr/share/gnupg/help.*.txt \
    && ln -sf /usr/bin/fdfind /usr/bin/fd

# Create non-root user with fish as default shell
RUN useradd -m -u 1000 -d /home/monk -s /usr/local/bin/fish monk && \
    mkdir -p /workspace && \
    chown monk:monk /workspace

# Copy vfox, zellij, lazygit, fish, claude, and ast-grep from builder
COPY --from=builder /usr/local/bin/vfox /usr/local/bin/zellij /usr/local/bin/lazygit /usr/local/bin/fish /usr/local/bin/claude /usr/local/bin/ast-grep /usr/local/bin/

# Copy global npm packages from builder and create symlinks
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/typescript/bin/tsc /usr/local/bin/tsc && \
    ln -sf /usr/local/lib/node_modules/typescript/bin/tsserver /usr/local/bin/tsserver && \
    ln -sf /usr/local/lib/node_modules/ts-node/dist/bin.js /usr/local/bin/ts-node && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Switch to monk user for remaining setup
USER monk
WORKDIR /home/monk

# Configure user directories
RUN mkdir -p /home/monk/.config/fish/conf.d && \
    mkdir -p /home/monk/.config/fish/functions && \
    mkdir -p /home/monk/.config/fish/completions && \
    mkdir -p /home/monk/.local/share/fish/generated_completions && \
    mkdir -p /home/monk/.local/bin && \
    mkdir -p /home/monk/.cache && \
    mkdir -p /home/monk/.version-fox && \
    mkdir -p /home/monk/.zsh-completions

# Generate shell completions for zellij and vfox
RUN zellij setup --generate-completion fish > /home/monk/.config/fish/completions/zellij.fish && \
    zellij setup --generate-completion zsh > /home/monk/.zsh-completions/_zellij && \
    vfox completion fish > /home/monk/.config/fish/completions/vfox.fish && \
    vfox completion zsh > /home/monk/.zsh-completions/_vfox

# Copy the banner generator; it is run once at build time (see below) to bake
# the greeting with fixed tool versions into a static file, then removed
COPY scripts/cloister-banner-gen /home/monk/.local/bin/cloister-banner-gen

# Create banner script (POSIX sh) - prints the pre-rendered banner; shown by
# the shell configs so it greets the first terminal and every zellij pane
RUN cat > /home/monk/.local/bin/cloister-banner << 'BANNEREOF'
#!/bin/sh
cat /home/monk/.local/share/cloister/banner
BANNEREOF

# Create entrypoint script (POSIX sh) - the banner is rendered by the shell
# config (cloister-banner), so this just launches the default shell
RUN cat > /home/monk/.local/bin/cloister-start << 'STARTEOF'
#!/bin/sh
# Cloister entrypoint
exec /usr/local/bin/fish
STARTEOF
RUN chmod +x /home/monk/.local/bin/cloister-banner /home/monk/.local/bin/cloister-start

# Configure fish shell
RUN cat > /home/monk/.config/fish/config.fish << 'FISHEOF'
# Cloister Fish Configuration
set -gx PATH /home/monk/.local/bin /usr/local/bin /usr/bin /bin $PATH
set -gx HOME /home/monk
set -gx LANG C.UTF-8
set -gx LC_ALL C.UTF-8
set -gx VFOX_HOME /home/monk/.version-fox
set -gx NPM_CONFIG_PREFIX /home/monk/.npm-global

# Initialize vfox if available
if type -q vfox
    vfox activate fish | source
end

# Show the Cloister banner once per interactive terminal / zellij pane
if status is-interactive
    set -l __banner_marker /tmp/.cloister-banner-(tty | string replace -a / _)
    if not test -e $__banner_marker
        cloister-banner
        touch $__banner_marker 2>/dev/null
    end
end
FISHEOF

# Configure zsh shell
RUN cat > /home/monk/.zshrc << 'ZSHEOF'
# Cloister Zsh Configuration
export PATH="/home/monk/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="/home/monk"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export VFOX_HOME="/home/monk/.version-fox"
export NPM_CONFIG_PREFIX="/home/monk/.npm-global"

# Initialize vfox if available
if command -v vfox &> /dev/null; then
    eval "$(vfox activate zsh)"
fi

# Zellij completions
fpath=(~/.zsh-completions $fpath)
autoload -Uz compinit && compinit

# Show the Cloister banner once per interactive terminal / zellij pane
if [[ -o interactive ]]; then
    __banner_marker="/tmp/.cloister-banner-$(tty 2>/dev/null | tr / _)"
    if [[ ! -e "$__banner_marker" ]]; then
        cloister-banner
        touch "$__banner_marker" 2>/dev/null
    fi
    unset __banner_marker
fi
ZSHEOF

# Create npm global directory for user installations
RUN mkdir -p /home/monk/.npm-global

# Set environment variables
ENV PATH="/home/monk/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="/home/monk" \
    XDG_DATA_HOME="/home/monk/.local/share" \
    XDG_CONFIG_HOME="/home/monk/.config" \
    XDG_CACHE_HOME="/home/monk/.cache" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    VFOX_HOME="/home/monk/.version-fox" \
    NPM_CONFIG_PREFIX="/home/monk/.npm-global" \
    SHELL="/usr/local/bin/fish"

# Pre-render the banner now that every tool is on PATH; versions are fixed at
# build time, so shells cat this file instead of probing versions on startup
RUN mkdir -p /home/monk/.local/share/cloister && \
    sh /home/monk/.local/bin/cloister-banner-gen > /home/monk/.local/share/cloister/banner && \
    rm /home/monk/.local/bin/cloister-banner-gen

WORKDIR /workspace

# Default command - entrypoint
CMD ["/home/monk/.local/bin/cloister-start"]

# =============================================================================
# OCI Labels
# =============================================================================
LABEL org.opencontainers.image.title="Cloister" \
      org.opencontainers.image.description="Development environment with Fish shell, Node.js, TypeScript, Python, Claude Code CLI, git, and vfox" \
      org.opencontainers.image.vendor="Cloister" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jogai/cloister" \
      org.opencontainers.image.documentation="https://github.com/jogai/cloister#readme"
