# Cloister - Distroless Development Environment with Fish Shell
# Multi-stage build using Chainguard Wolfi for minimal attack surface
#
# Build:
#   docker build -t cloister .
#
# Features:
#   - Wolfi-based (distroless-inspired, minimal packages)
#   - No package manager in final image
#   - Fish shell, Python, Node.js, TypeScript, Claude Code CLI, vfox

# =============================================================================
# Stage 1: Builder - Compile and prepare all artifacts
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest@sha256:caa431d92d0b6f31c4845ddca9c4dd813d5f488ba0e3416ff6135d83b2f1c068 AS builder

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    git

# renovate: datasource=github-releases depName=version-fox/vfox
ARG VFOX_VERSION=1.0.2

# renovate: datasource=github-releases depName=zellij-org/zellij
ARG ZELLIJ_VERSION=0.43.1

# Download zellij and vfox binaries
RUN mkdir -p /usr/local/bin && \
    ARCH=$(uname -m) && \
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C /usr/local/bin && \
    curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash

# =============================================================================
# Stage 2: Node Builder - Prepare all npm packages
# =============================================================================
FROM cgr.dev/chainguard/node:latest-dev@sha256:1a1b3dbbd86860e72fe85ec11cf897a154e6053e850aa13136cb55bb2dfaa0d0 AS node-builder

USER root

# Install all global npm packages in a single layer
# renovate: datasource=npm depName=typescript
ARG TYPESCRIPT_VERSION=5.9.3
# renovate: datasource=npm depName=ts-node
ARG TS_NODE_VERSION=10.9.2
# renovate: datasource=npm depName=@types/node
ARG TYPES_NODE_VERSION=25.0.8
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.6

RUN npm install -g \
    typescript@${TYPESCRIPT_VERSION} \
    ts-node@${TS_NODE_VERSION} \
    @types/node@${TYPES_NODE_VERSION} \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm cache clean --force

# =============================================================================
# Stage 3: Final - Minimal runtime image (distroless-style)
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest@sha256:caa431d92d0b6f31c4845ddca9c4dd813d5f488ba0e3416ff6135d83b2f1c068 AS final

# Install only runtime dependencies using Wolfi package names
RUN apk add --no-cache \
    ca-certificates-bundle \
    curl \
    wget \
    fish \
    zsh \
    git \
    git-lfs \
    lazygit \
    gnupg \
    xz \
    gzip \
    unzip \
    jq \
    less \
    nodejs \
    npm \
    openssh-client \
    ripgrep \
    fd \
    fzf \
    python3 \
    py3-pip \
    tree

# Create non-root user with sh as default shell
RUN adduser -D -u 1000 -h /home/monk -s /bin/sh monk && \
    mkdir -p /workspace && \
    chown monk:monk /workspace

# Copy vfox and zellij from builder
COPY --from=builder /usr/local/bin/vfox /usr/local/bin/zellij /usr/local/bin/

# Copy global npm packages from node-builder and create symlinks
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/typescript/bin/tsc /usr/local/bin/tsc && \
    ln -sf /usr/local/lib/node_modules/typescript/bin/tsserver /usr/local/bin/tsserver && \
    ln -sf /usr/local/lib/node_modules/ts-node/dist/bin.js /usr/local/bin/ts-node && \
    ln -sf /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js /usr/local/bin/claude

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

# Create entrypoint script with greeting (POSIX sh)
RUN cat > /home/monk/.local/bin/cloister-start << 'STARTEOF'
#!/bin/sh
# Cloister entrypoint

# ANSI color codes
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Greeting
printf "${CYAN}🏛  Cloister Development Environment${NC}\n"

# Print tool versions
for tool in "Git:git" "Python:python" "Node.js:node" "npm:npm" "TypeScript:tsc" "Claude:claude" "vfox:vfox" "Zellij:zellij" "Fish:fish" "Zsh:zsh"; do
    name="${tool%%:*}"
    cmd="${tool#*:}"
    version=$($cmd --version 2>/dev/null | sed 's/^[^0-9]*//' | head -n1)
    printf "   %-11s%s\n" "$name:" "$version"
done
echo ""

# Usage instructions
printf "${GRAY}Available shells:${NC}\n"
echo "   zsh      - Powerful shell with great plugin ecosystem"
echo "   fish     - Friendly shell with autosuggestions"
echo ""
printf "${GRAY}Terminal multiplexer:${NC}\n"
echo "   zellij   - Split panes, run Claude, fish, and zsh all at once"
echo ""
printf "${GRAY}AI assistant:${NC}\n"
echo "   claude --dangerously-skip-permissions"
echo ""

# Start default shell
exec /bin/sh
STARTEOF
RUN chmod +x /home/monk/.local/bin/cloister-start

# Configure fish shell
RUN cat > /home/monk/.config/fish/config.fish << 'FISHEOF'
# Cloister Fish Configuration
set -gx PATH /home/monk/.local/bin /usr/local/bin /usr/bin /bin $PATH
set -gx HOME /home/monk
set -gx PYTHONUNBUFFERED 1
set -gx PYTHONDONTWRITEBYTECODE 1
set -gx LANG C.UTF-8
set -gx LC_ALL C.UTF-8
set -gx VFOX_HOME /home/monk/.version-fox
set -gx NPM_CONFIG_PREFIX /home/monk/.npm-global

# Initialize vfox if available
if type -q vfox
    vfox activate fish | source
end
FISHEOF

# Configure zsh shell
RUN cat > /home/monk/.zshrc << 'ZSHEOF'
# Cloister Zsh Configuration
export PATH="/home/monk/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="/home/monk"
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
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
ZSHEOF

# Create npm global directory for user installations
RUN mkdir -p /home/monk/.npm-global

# Set environment variables
ENV PATH="/home/monk/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="/home/monk" \
    XDG_DATA_HOME="/home/monk/.local/share" \
    XDG_CONFIG_HOME="/home/monk/.config" \
    XDG_CACHE_HOME="/home/monk/.cache" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    VFOX_HOME="/home/monk/.version-fox" \
    NPM_CONFIG_PREFIX="/home/monk/.npm-global" \
    SHELL="/bin/sh"

WORKDIR /workspace

# Default command - entrypoint
CMD ["/home/monk/.local/bin/cloister-start"]

# =============================================================================
# OCI Labels
# =============================================================================
LABEL org.opencontainers.image.title="Cloister" \
      org.opencontainers.image.description="Distroless development environment with Fish shell, Python, Node.js, TypeScript, Claude Code CLI, git, and vfox" \
      org.opencontainers.image.vendor="Cloister" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jogai/cloister" \
      org.opencontainers.image.documentation="https://github.com/jogai/cloister#readme"
