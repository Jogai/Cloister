# 🏛️ Cloister

A minimal Alpine-based Docker image with Fish shell for development environments featuring Python, Node.js, TypeScript, Claude Code CLI, git, pipx, and vfox version manager.

## ✨ Features

- 🏔️ **Alpine Linux** - Minimal base image (~5MB)
- 🐟 **Fish Shell** - Friendly interactive shell with syntax highlighting and autosuggestions
- 🐍 **Python 3** with pipx for isolated tool installations
- 💚 **Node.js** with npm (Alpine native)
- 🔷 **TypeScript** with ts-node for direct execution
- 🤖 **Claude Code CLI** - Anthropic's official CLI for Claude
- 📦 **git** with git-lfs - Version control
- 🦊 **vfox** - Universal version manager (pre-configured for Fish)

## 🚀 Quick Start

### Pull the image

```bash
docker pull ghcr.io/jogai/cloister:latest
```

### Run interactively

```bash
docker run -it --rm ghcr.io/jogai/cloister:latest
```

You'll be greeted with a Fish shell showing version info for all tools.

### Mount your project

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/jogai/cloister:latest
```

### Use Claude Code CLI

```bash
docker run -it --rm \
  -e ANTHROPIC_API_KEY=your-api-key \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/jogai/cloister:latest \
  claude "Help me with this code"
```

### Use with persistent Claude config

Mount your local Claude configuration to preserve settings, history, and authentication:

```bash
docker run -it --rm \
  -v ~/.claude:/home/claude/.claude \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/jogai/cloister:latest
```

Or create an alias for convenience:

```bash
alias cloister='docker run -it --rm -v ~/.claude:/home/claude/.claude -v $(pwd):/workspace -w /workspace ghcr.io/jogai/cloister:latest'
```

### Run a specific command

```bash
# Run Python script
docker run -it --rm -v $(pwd):/workspace ghcr.io/jogai/cloister:latest python3 script.py

# Run TypeScript
docker run -it --rm -v $(pwd):/workspace ghcr.io/jogai/cloister:latest ts-node app.ts

# Use vfox to install a specific Node version
docker run -it --rm ghcr.io/jogai/cloister:latest fish -c "vfox install nodejs@20"
```

## 📦 Image Variants

### Full (Default)

Based on Alpine with Fish shell, includes all tools with full functionality:

```bash
docker pull ghcr.io/jogai/cloister:latest
# or explicitly
docker pull ghcr.io/jogai/cloister:full
```

### Slim

Reduced size image with essential tools only:

```bash
docker pull ghcr.io/jogai/cloister:slim
```

## 🔨 Building Locally

```bash
# Build the full image (recommended)
docker build --target full -t cloister:full .

# Build the slim image
docker build --target slim -t cloister:slim .

# Build for specific architecture
docker buildx build --platform linux/amd64 --target full -t cloister:full .
```

## 🐟 Fish Shell Features

The container uses Fish as the default shell with:

- **Welcome message** showing Python, Node.js, and TypeScript versions
- **vfox integration** - Automatically activated for version management
- **Syntax highlighting** - Built-in command highlighting
- **Autosuggestions** - Fish suggests commands as you type
- **Tab completion** - Smart completions for commands and paths

### Fish Configuration

The Fish config is located at `/home/claude/.config/fish/config.fish` and includes:

```fish
# vfox is auto-activated
vfox activate fish | source

# All tools are in PATH
set -gx PATH /home/claude/.local/bin /usr/local/bin /usr/bin /bin $PATH
```

### Using Bash Commands

If you need bash compatibility for scripts:

```bash
docker run -it --rm ghcr.io/jogai/cloister:latest sh -c "your-bash-script.sh"
```

## 🛠️ Tool Versions

| Tool | Version |
|------|---------|
| Alpine | latest |
| Fish | Alpine package |
| Node.js | Alpine package |
| Python | Alpine package |
| pipx | Alpine package |
| TypeScript | Latest npm |
| Claude CLI | Latest npm |
| vfox | 0.6.1 |

## ⚙️ Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | API key for Claude Code CLI | - |
| `NODE_ENV` | Node.js environment | production |
| `PYTHONUNBUFFERED` | Unbuffered Python output | 1 |
| `LANG` | System locale | C.UTF-8 |
| `VFOX_HOME` | vfox configuration directory | /home/claude/.version-fox |
| `SHELL` | Default shell | /usr/bin/fish |

## 🔒 Security

- Runs as non-root user (`claude` with UID 1000)
- Minimal Alpine base image (~5MB base)
- Regular security scanning via Trivy
- SBOM and provenance attestations included
- Multi-architecture support (amd64, arm64)

## 🔄 GitHub Actions Workflow

The image is automatically built and pushed to GHCR on:

- Push to `main` or `master` branches
- Git tags matching `v*.*.*`
- Manual workflow dispatch

### Workflow Features

- Multi-architecture builds (amd64, arm64)
- Layer caching for faster builds
- Automatic security scanning with Trivy
- SBOM generation
- Build provenance attestation
- Comprehensive tool testing

### Manual Trigger Options

When triggering the workflow manually, you can specify:

- **image_tag**: Custom tag for the image
- **build_target**: Choose between `full`, `slim`, or `all`
- **platforms**: Target `linux/amd64`, `linux/arm64`, or both

## 🐙 Container Registry

Images are published to GitHub Container Registry (ghcr.io):

```bash
# Full image (default)
ghcr.io/jogai/cloister:latest
ghcr.io/jogai/cloister:full
ghcr.io/jogai/cloister:v1.0.0

# Slim image
ghcr.io/jogai/cloister:slim
ghcr.io/jogai/cloister:v1.0.0-slim

# SHA-based tags
ghcr.io/jogai/cloister:sha-abc1234
```

## 📄 License

MIT License
