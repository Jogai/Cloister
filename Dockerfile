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
FROM cgr.dev/chainguard/wolfi-base:latest@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175 AS builder

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    git

# Download vfox using official install script
RUN curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash

# =============================================================================
# Stage 2: Node Builder - Prepare all npm packages
# =============================================================================
FROM cgr.dev/chainguard/node:latest-dev@sha256:bead3b22234bc8406318839695d40d57b16694f833f0cd64f5180ed764952e13 AS node-builder

USER root

# Install all global npm packages in a single layer
# renovate: datasource=npm depName=typescript
ARG TYPESCRIPT_VERSION=5.9.3
# renovate: datasource=npm depName=ts-node
ARG TS_NODE_VERSION=10.9.2
# renovate: datasource=npm depName=@types/node
ARG TYPES_NODE_VERSION=25.0.3
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.2

RUN npm install -g \
    typescript@${TYPESCRIPT_VERSION} \
    ts-node@${TS_NODE_VERSION} \
    @types/node@${TYPES_NODE_VERSION} \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm cache clean --force

# =============================================================================
# Stage 3: Final - Minimal runtime image (distroless-style)
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175 AS final

# Install only runtime dependencies using Wolfi package names
RUN apk add --no-cache \
    ca-certificates-bundle \
    fish \
    zsh \
    git \
    git-lfs \
    openssh-client \
    xz \
    unzip \
    gzip \
    nodejs \
    npm \
    python3 \
    py3-pip \
    jq \
    gnupg \
    curl \
    lazygit

# Create non-root user with sh as default shell
RUN adduser -D -u 1000 -h /home/monk -s /bin/sh monk && \
    mkdir -p /workspace && \
    chown monk:monk /workspace

# Copy vfox from builder
COPY --from=builder /usr/local/bin/vfox /usr/local/bin/vfox

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
    mkdir -p /home/monk/.version-fox

# Create entrypoint script with greeting
RUN cat > /home/monk/.local/bin/cloister-start << 'STARTEOF'
#!/usr/bin/fish
# Cloister entrypoint

# Greeting
set_color cyan
echo "🏛  Cloister Development Environment"
set_color normal
for tool in git:git Python:python Node.js:node npm:npm TypeScript:tsc Claude:claude vfox:vfox fish:fish zsh:zsh
    set -l parts (string split ':' $tool)
    printf "   %-11s%s\n" "$parts[1]:" ($parts[2] --version 2>/dev/null | string replace -r '^\D*' '')
end
echo ""

# Usage instructions
set_color brblack
echo "Available shells:"
set_color normal
echo "   zsh      - Z shell"
echo "   fish     - Fish shell"
echo ""
set_color brblack
echo "Start Claude Code CLI:"
set_color normal
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
    SHELL="/bin/zsh"

WORKDIR /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node --version && python3 --version && git --version

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
