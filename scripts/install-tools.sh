#!/bin/sh
# Download and install the pinned tool binaries into /usr/local/bin:
# zellij, lazygit, fish, ast-grep, rtk (checksum-verified), vfox, and claude
# (checksum-verified).
#
# Versions are provided by the Dockerfile build ARGs, passed in as environment
# variables. TARGETARCH selects the architecture (amd64 / arm64).
set -e

mkdir -p /usr/local/bin

ARCH=$(uname -m)
LAZYGIT_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "arm64")
FISH_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64")
AST_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64")

# zellij
curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C /usr/local/bin

# lazygit
curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz" | tar -xz -C /usr/local/bin lazygit

# fish
curl -fsSL "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${FISH_ARCH}.tar.xz" | tar -xJ -C /usr/local/bin

# ast-grep
curl -fsSL "https://github.com/ast-grep/ast-grep/releases/download/${ASTGREP_VERSION}/app-${AST_ARCH}-unknown-linux-gnu.zip" -o /tmp/ast-grep.zip
unzip -o /tmp/ast-grep.zip ast-grep -d /usr/local/bin
rm /tmp/ast-grep.zip

# rtk (x86_64 ships a musl build, aarch64 a gnu build; verify against the release checksums)
RTK_TARGET=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64-unknown-linux-musl" || echo "aarch64-unknown-linux-gnu")
RTK_ASSET="rtk-${RTK_TARGET}.tar.gz"
RTK_URL="https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}"
curl -fsSL "$RTK_URL/$RTK_ASSET" -o "/tmp/$RTK_ASSET"
RTK_EXPECTED=$(curl -fsSL "$RTK_URL/checksums.txt" | grep " $RTK_ASSET\$" | cut -d' ' -f1)
RTK_ACTUAL=$(sha256sum "/tmp/$RTK_ASSET" | cut -d' ' -f1)
[ -n "$RTK_EXPECTED" ] && [ "$RTK_ACTUAL" = "$RTK_EXPECTED" ] || { echo "rtk checksum verification failed"; exit 1; }
tar -xz -C /usr/local/bin -f "/tmp/$RTK_ASSET" rtk
rm "/tmp/$RTK_ASSET"

# vfox
curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash

# claude (verify the published checksum before trusting the binary)
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
PLATFORM="linux-$([ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64")"
CHECKSUM=$(curl -fsSL "$GCS_BUCKET/$CLAUDE_CODE_VERSION/manifest.json" | jq -r ".platforms[\"$PLATFORM\"].checksum")
curl -fsSL "$GCS_BUCKET/$CLAUDE_CODE_VERSION/$PLATFORM/claude" -o /usr/local/bin/claude
ACTUAL=$(sha256sum /usr/local/bin/claude | cut -d' ' -f1)
[ "$ACTUAL" = "$CHECKSUM" ] || { echo "Checksum verification failed"; exit 1; }
chmod +x /usr/local/bin/claude
