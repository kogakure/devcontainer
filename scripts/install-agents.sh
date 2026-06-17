#!/usr/bin/env bash
# install-agents.sh — runs as vscode user at Docker build time
# Installs all AI agents: Claude Code, Codex, OpenCode, Pi Agent, Grok.
set -euo pipefail

# npm prefix → ~/.local/bin (already on PATH in fish config)
npm config set prefix "$HOME/.local"
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"

# ── Claude Code ───────────────────────────────────────────────────────────────
# Auth at runtime via bind-mounted ~/.claude/.credentials.json
npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code

# ── Codex ─────────────────────────────────────────────────────────────────────
# Auth at runtime via bind-mounted ~/.codex/
npm install -g @openai/codex

# ── OpenCode ──────────────────────────────────────────────────────────────────
# Official installer drops binary to ~/.local/bin
curl -fsSL https://opencode.ai/install | bash || \
    npm install -g opencode-ai 2>/dev/null || \
    echo "⚠️  OpenCode install skipped — install manually if needed"

# ── Pi Agent ──────────────────────────────────────────────────────────────────
# Installed to ~/.local/pi-agent-npm (config.fish:100 prepends this to PATH)
# Auth at runtime via bind-mounted ~/.pi/agent/auth.json
mkdir -p "$HOME/.local/pi-agent-npm"
npm install -g --prefix "$HOME/.local/pi-agent-npm" \
    @earendil-works/pi-coding-agent \
    @nqbao/pi-sandbox \
    pi-subagents \
    pi-defender \
    pi-agent-browser-native 2>/dev/null || \
    echo "⚠️  Some Pi Agent packages unavailable — mount ~/.pi/agent/auth.json first"

# ── Grok ──────────────────────────────────────────────────────────────────────
# Official xAI Grok CLI → ~/.grok/bin (config.fish:103 adds to PATH)
# Auth at runtime via bind-mounted ~/.grok
curl -fsSL https://grok.x.ai/install.sh | sh 2>/dev/null || \
    curl -fsSL https://x.ai/grok/install.sh | sh 2>/dev/null || \
    echo "⚠️  Grok CLI install skipped — install manually or bind-mount from host"

echo "✓ Agent install complete"
