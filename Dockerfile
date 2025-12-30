# Cloister - Distroless Development Environment with Fish Shell
# Multi-stage build using Chainguard Wolfi for minimal attack surface
#
# Build:
#   docker build -t cloister .
#
# Features:
#   - Wolfi-based (distroless-inspired, minimal packages)
#   - No package manager in final image
#   - Fish shell, Python, Node.js, TypeScript, Claude CLI, vfox

# =============================================================================
# Stage 1: Builder - Compile and prepare all artifacts
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    git

# Download vfox using official install script
RUN curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash

# =============================================================================
# Stage 2: Node Builder - Prepare npm packages
# =============================================================================
FROM cgr.dev/chainguard/node:latest-dev AS node-builder

USER root

# Install global npm packages
RUN npm install -g \
    typescript \
    ts-node \
    @types/node \
    && npm cache clean --force

# =============================================================================
# Stage 3: Claude Builder - Install Claude CLI
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS claude-builder

RUN apk add --no-cache curl bash glibc-locale-posix

# Install Claude Code (creates files in /root/.claude and /usr/local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash

# =============================================================================
# Stage 4: Final - Minimal runtime image (distroless-style)
# =============================================================================
FROM cgr.dev/chainguard/wolfi-base:latest AS final

# Install only runtime dependencies using Wolfi package names
RUN apk add --no-cache \
    ca-certificates-bundle \
    fish \
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
    gnupg

# Create non-root user with fish as default shell
RUN adduser -D -u 1000 -h /home/monk -s /usr/bin/fish monk && \
    mkdir -p /workspace && \
    chown monk:monk /workspace

# Copy vfox from builder
COPY --from=builder /usr/local/bin/vfox /usr/local/bin/vfox

# Copy global npm packages from node-builder
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/typescript/bin/tsc /usr/local/bin/tsc && \
    ln -sf /usr/local/lib/node_modules/typescript/bin/tsserver /usr/local/bin/tsserver && \
    ln -sf /usr/local/lib/node_modules/ts-node/dist/bin.js /usr/local/bin/ts-node

# Copy Claude CLI from claude-builder and fix ownership
COPY --from=claude-builder /root/.claude /home/monk/.claude
RUN chown -R monk:monk /home/monk/.claude && \
    ln -s /home/monk/.claude/local/claude /usr/local/bin/claude

# Switch to monk user for remaining setup
USER monk
WORKDIR /home/monk

# Initialize vfox for monk user
RUN mkdir -p /home/monk/.version-fox

# Configure fish shell
RUN mkdir -p /home/monk/.config/fish/conf.d && \
    mkdir -p /home/monk/.config/fish/functions

# Create fish config with vfox hook and PATH
RUN cat > /home/monk/.config/fish/config.fish << 'FISHEOF'
# Cloister Fish Configuration

# Environment variables
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

# Create fish greeting function
RUN cat > /home/monk/.config/fish/functions/fish_greeting.fish << 'FISHEOF'
function fish_greeting
    set_color cyan
    echo "🏛️  Cloister Development Environment"
    set_color normal
    echo "   Python:     "(python --version 2>/dev/null | string replace -r '^\D*' '')
    echo "   Node.js:    "(node --version 2>/dev/null | string replace -r '^\D*' '')
    echo "   npm:        "(npm --version 2>/dev/null | string replace -r '^\D*' '')
    echo "   TypeScript: "(tsc --version 2>/dev/null | string replace -r '^\D*' '')
    echo "   Claude:     "(claude --version 2>/dev/null | string replace -r '^\D*' '')
    echo "   vfox:       "(vfox --version 2>/dev/null | head -1 | string replace -r '^\D*' '')
    echo ""
end
FISHEOF

# Create npm global directory for user installations
RUN mkdir -p /home/monk/.npm-global

# Set environment variables
ENV PATH="/home/monk/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="/home/monk" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    VFOX_HOME="/home/monk/.version-fox" \
    NPM_CONFIG_PREFIX="/home/monk/.npm-global" \
    SHELL="/usr/bin/fish"

WORKDIR /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node --version && python3 --version && git --version

# Default command - fish shell
CMD ["/usr/bin/fish"]

# =============================================================================
# OCI Labels
# =============================================================================
LABEL org.opencontainers.image.title="Cloister" \
      org.opencontainers.image.description="Distroless development environment with Fish shell, Python, Node.js, TypeScript, Claude CLI, git, and vfox" \
      org.opencontainers.image.vendor="Cloister" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jogai/cloister" \
      org.opencontainers.image.documentation="https://github.com/jogai/cloister#readme"
