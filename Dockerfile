FROM mcr.microsoft.com/devcontainers/base:debian-12

# ── Build-time metadata ───────────────────────────────────────────────────────
LABEL org.opencontainers.image.source="https://github.com/kogakure/devcontainer"
LABEL org.opencontainers.image.description="AI-agent dev environment: Fish + Starship + Claude/Codex/OpenCode/Pi/Grok"
LABEL org.opencontainers.image.licenses="MIT"

# ── Portable env (no Mac paths) ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    XDG_CACHE_HOME=/home/vscode/.cache \
    XDG_CONFIG_HOME=/home/vscode/.config \
    XDG_DATA_HOME=/home/vscode/.local/share \
    XDG_STATE_HOME=/home/vscode/.local/state \
    EDITOR=nvim \
    PNPM_HOME=/home/vscode/.local/share/pnpm

# ── Scripts ───────────────────────────────────────────────────────────────────
COPY scripts/ /tmp/dc-scripts/
RUN chmod +x /tmp/dc-scripts/*.sh

# ── Layer 1: system tools (root) ──────────────────────────────────────────────
RUN /tmp/dc-scripts/install-tools.sh

# ── Layer 2: agents + user-local npm (vscode user) ───────────────────────────
USER vscode
WORKDIR /home/vscode
ENV HOME=/home/vscode \
    PATH="/home/vscode/.local/bin:/home/vscode/.local/pi-agent-npm/bin:/home/vscode/.grok/bin:/home/vscode/.opencode/bin:/home/vscode/.cargo/bin:/home/vscode/.local/share/pnpm:/home/vscode/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN /tmp/dc-scripts/install-agents.sh

# ── Layer 3: public dotfiles (vscode user) ────────────────────────────────────
RUN /tmp/dc-scripts/bootstrap-dotfiles.sh

# ── Clean up scripts ──────────────────────────────────────────────────────────
USER root
RUN rm -rf /tmp/dc-scripts

# ── Set fish as default login shell for vscode user ──────────────────────────
USER root
RUN chsh -s /usr/bin/fish vscode

# ── Default to fish as vscode user ───────────────────────────────────────────
USER vscode
WORKDIR /home/vscode
CMD ["/usr/bin/fish", "--login"]
