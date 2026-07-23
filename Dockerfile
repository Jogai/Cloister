# Stage 1: Builder - Prepare all artifacts
FROM cgr.dev/chainguard/node:latest-dev@sha256:f29c00607fd8fa702c91856895fd8819cd62c83bbe3a2195540abe05359fdf54 AS builder

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
ARG LAZYGIT_VERSION=0.63.1

# renovate: datasource=github-releases depName=fish-shell/fish-shell
ARG FISH_VERSION=4.8.1

# renovate: datasource=github-releases depName=ast-grep/ast-grep
ARG ASTGREP_VERSION=0.44.1

# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.215

# renovate: datasource=npm depName=typescript
ARG TYPESCRIPT_VERSION=7.0.2
# renovate: datasource=npm depName=ts-node
ARG TS_NODE_VERSION=10.9.2

# Install the pinned tool binaries (scripts/install-tools.sh); version ARGs are passed through so bumping any of them busts the cache
ARG TARGETARCH
COPY scripts/install-tools.sh /tmp/install-tools.sh
RUN TARGETARCH="${TARGETARCH}" \
    ZELLIJ_VERSION="${ZELLIJ_VERSION}" \
    LAZYGIT_VERSION="${LAZYGIT_VERSION}" \
    FISH_VERSION="${FISH_VERSION}" \
    ASTGREP_VERSION="${ASTGREP_VERSION}" \
    CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION}" \
    sh /tmp/install-tools.sh && rm /tmp/install-tools.sh

# Install global npm packages
RUN npm install -g \
    npm \
    typescript@${TYPESCRIPT_VERSION} \
    ts-node@${TS_NODE_VERSION} \
    @types/node \
    && npm cache clean --force

# Stage 2: Final - Runtime image
FROM ghcr.io/astral-sh/uv:python3.14-trixie-slim@sha256:78923b1c11ab847cc275c5706c70debc9eac743f935d7ad11966c1c983236aa3 AS final

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

# Copy the banner generator; run once at build time (below) to bake the greeting into a static file, then removed
COPY scripts/cloister-banner-gen /home/monk/.local/bin/cloister-banner-gen

# Copy runtime scripts: cloister-banner prints the pre-rendered banner, cloister-start is the entrypoint
COPY scripts/cloister-banner scripts/cloister-start /home/monk/.local/bin/

# Configure fish and zsh shells
COPY config/config.fish /home/monk/.config/fish/config.fish
COPY config/zshrc /home/monk/.zshrc

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

# Pre-render the banner now that every tool is on PATH, so shells cat this file instead of probing versions on startup
RUN mkdir -p /home/monk/.local/share/cloister && \
    sh /home/monk/.local/bin/cloister-banner-gen > /home/monk/.local/share/cloister/banner && \
    rm /home/monk/.local/bin/cloister-banner-gen

WORKDIR /workspace

# Default command - entrypoint
CMD ["/home/monk/.local/bin/cloister-start"]

# OCI Labels
LABEL org.opencontainers.image.title="Cloister" \
      org.opencontainers.image.description="Development environment with Fish shell, Node.js, TypeScript, Python, Claude Code CLI, git, and vfox" \
      org.opencontainers.image.vendor="Cloister" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jogai/cloister" \
      org.opencontainers.image.documentation="https://github.com/jogai/cloister#readme"
