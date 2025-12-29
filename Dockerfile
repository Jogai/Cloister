# Cloister - Alpine-based Development Environment with Fish Shell
# Multi-stage build for minimal image with development tools
#
# Build targets:
#   - full: Complete development environment (default, recommended)
#   - slim: Reduced size with essential tools only
#
# Usage:
#   docker build --target full -t cloister:full .
#   docker build --target slim -t cloister:slim .

# =============================================================================
# Stage 1: Builder - Download vfox
# =============================================================================
FROM alpine:latest AS builder

ARG VFOX_VERSION=0.6.1

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

WORKDIR /build

# Download vfox based on architecture
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then VFOX_ARCH="x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then VFOX_ARCH="aarch64"; \
    else VFOX_ARCH="$ARCH"; fi && \
    curl -fsSL "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/vfox_${VFOX_VERSION}_linux_${VFOX_ARCH}.tar.gz" | \
    tar -xz && \
    chmod +x vfox

# =============================================================================
# Stage 2: Full - Complete development environment (RECOMMENDED)
# =============================================================================
FROM alpine:latest AS full

# Install runtime dependencies using Alpine native packages
RUN apk add --no-cache \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    # Shell
    fish \
    # Version control
    git \
    git-lfs \
    openssh-client \
    # Compression tools
    xz \
    unzip \
    tar \
    gzip \
    # Node.js and npm (Alpine native - works with musl)
    nodejs \
    npm \
    # Python ecosystem
    python3 \
    py3-pip \
    py3-virtualenv \
    # JSON processing
    jq \
    # GPG for verification
    gnupg \
    # Shadow for user management
    shadow

# Create non-root user with fish as default shell
RUN addgroup -g 1000 claude && \
    adduser -D -u 1000 -G claude -s /usr/bin/fish -h /home/claude claude && \
    mkdir -p /workspace && \
    chown claude:claude /workspace

# Copy vfox from builder
COPY --from=builder /build/vfox /usr/local/bin/vfox

# Install global npm packages as root (will be available to all users)
RUN npm install -g \
    typescript \
    ts-node \
    @types/node \
    @anthropic-ai/claude-code \
    && npm cache clean --force

# Switch to claude user for remaining setup
USER claude
WORKDIR /home/claude

# Install pipx for the claude user
RUN python3 -m pip install --user --break-system-packages pipx && \
    python3 -m pipx ensurepath

# Initialize vfox for claude user
RUN mkdir -p /home/claude/.version-fox

# Configure fish shell
RUN mkdir -p /home/claude/.config/fish/conf.d && \
    mkdir -p /home/claude/.config/fish/functions

# Create fish config with vfox hook and PATH
RUN cat > /home/claude/.config/fish/config.fish << 'FISHEOF'
# Cloister Fish Configuration

# Environment variables
set -gx PATH /home/claude/.local/bin /usr/local/bin /usr/bin /bin $PATH
set -gx HOME /home/claude
set -gx NODE_ENV production
set -gx PYTHONUNBUFFERED 1
set -gx PYTHONDONTWRITEBYTECODE 1
set -gx LANG C.UTF-8
set -gx LC_ALL C.UTF-8
set -gx VFOX_HOME /home/claude/.version-fox
set -gx NPM_CONFIG_PREFIX /home/claude/.npm-global

# Initialize vfox if available
if type -q vfox
    vfox activate fish | source
end
FISHEOF

# Create fish greeting function
RUN cat > /home/claude/.config/fish/functions/fish_greeting.fish << 'FISHEOF'
function fish_greeting
    set_color cyan
    echo "🏛️  Cloister Development Environment"
    set_color normal
    echo "   Python:     "(python3 --version 2>/dev/null | string replace "Python " "")
    echo "   Node.js:    "(node --version 2>/dev/null)
    echo "   npm:        "(npm --version 2>/dev/null)
    echo "   TypeScript: "(tsc --version 2>/dev/null | string replace "Version " "")
    echo "   vfox:       "(vfox --version 2>/dev/null | head -1)
    echo ""
end
FISHEOF

# Create npm global directory for user installations
RUN mkdir -p /home/claude/.npm-global

# Set environment variables (also needed for non-fish invocations)
ENV PATH="/home/claude/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="/home/claude" \
    NODE_ENV="production" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    VFOX_HOME="/home/claude/.version-fox" \
    NPM_CONFIG_PREFIX="/home/claude/.npm-global" \
    SHELL="/usr/bin/fish"

WORKDIR /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node --version && python3 --version && git --version

# Default command - fish shell
CMD ["/usr/bin/fish"]

# =============================================================================
# Stage 3: Slim - Minimal image with reduced size
# =============================================================================
FROM alpine:latest AS slim

# Install only essential runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    fish \
    git \
    openssh-client \
    nodejs \
    npm \
    python3 \
    py3-pip

# Create non-root user with fish shell
RUN addgroup -g 1000 claude && \
    adduser -D -u 1000 -G claude -s /usr/bin/fish -h /home/claude claude && \
    mkdir -p /workspace && \
    chown claude:claude /workspace

# Copy vfox from builder
COPY --from=builder /build/vfox /usr/local/bin/vfox

# Install essential npm packages
RUN npm install -g \
    typescript \
    @anthropic-ai/claude-code \
    && npm cache clean --force \
    && rm -rf /root/.npm/_cacache

# Switch to claude user
USER claude

# Install pipx
RUN python3 -m pip install --user --break-system-packages pipx

# Initialize vfox directory
RUN mkdir -p /home/claude/.version-fox

# Configure fish shell
RUN mkdir -p /home/claude/.config/fish/functions && \
    cat > /home/claude/.config/fish/config.fish << 'FISHEOF'
set -gx PATH /home/claude/.local/bin /usr/local/bin /usr/bin /bin $PATH
set -gx VFOX_HOME /home/claude/.version-fox
if type -q vfox
    vfox activate fish | source
end
FISHEOF

# Create fish greeting function
RUN cat > /home/claude/.config/fish/functions/fish_greeting.fish << 'FISHEOF'
function fish_greeting
    set_color cyan
    echo "🏛️  Cloister (slim)"
    set_color normal
end
FISHEOF

# Environment variables
ENV PATH="/home/claude/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    HOME="/home/claude" \
    NODE_ENV="production" \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    VFOX_HOME="/home/claude/.version-fox" \
    SHELL="/usr/bin/fish"

WORKDIR /workspace

CMD ["/usr/bin/fish"]

# =============================================================================
# OCI Labels (applied to all stages via build args)
# =============================================================================
LABEL org.opencontainers.image.title="Cloister" \
      org.opencontainers.image.description="Alpine-based development environment with Fish shell, Python, Node.js, TypeScript, Claude CLI, git, and vfox" \
      org.opencontainers.image.vendor="Cloister" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jogai/cloister" \
      org.opencontainers.image.documentation="https://github.com/jogai/cloister#readme"
