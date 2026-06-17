#!/usr/bin/env bash
# install-tools.sh — runs as root at Docker build time
# Installs apt packages + direct binary releases for Linux/arm64+amd64.
set -euo pipefail

ARCH="$(dpkg --print-architecture)"   # amd64 | arm64

# Get latest tag via HTTP redirect — no JSON API, no rate limits.
# GitHub /releases/latest redirects to /releases/tag/vX.Y.Z; extract the version.
gh_tag() {
    local tag
    tag=$(curl -sSI --max-time 15 "https://github.com/$1/releases/latest" \
        | grep -i '^location:' \
        | awk -F'/tag/' '{print $2}' \
        | tr -d '[:space:]\r\n')
    if [[ -z "$tag" ]]; then
        echo "ERROR: Could not resolve latest tag for $1" >&2
        exit 1
    fi
    echo "$tag"
}

# ── System packages ───────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y --no-install-recommends \
    ca-certificates curl wget gpg gnupg \
    git git-lfs \
    unzip p7zip-full \
    build-essential pkg-config cmake \
    ripgrep fd-find bat \
    jq \
    tree \
    htop \
    tmux \
    shellcheck \
    universal-ctags \
    direnv \
    locales \
    less man-db \
    openssh-client \
    python3 python3-pip

# Debian names fd/bat differently
ln -sf /usr/bin/fdfind /usr/local/bin/fd  2>/dev/null || true
ln -sf /usr/bin/batcat  /usr/local/bin/bat 2>/dev/null || true

# Locale
sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen

# ── Fish shell ────────────────────────────────────────────────────────────────
apt-get install -y --no-install-recommends fish || {
    # Fallback: fish OBS repo
    echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_12/ /' \
        > /etc/apt/sources.list.d/shells_fish.list
    curl -fsSL "https://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_12/Release.key" \
        | gpg --dearmor > /etc/apt/trusted.gpg.d/shells_fish.gpg
    apt-get update -qq
    apt-get install -y --no-install-recommends fish
}

# ── GitHub CLI ────────────────────────────────────────────────────────────────
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
apt-get update -qq
apt-get install -y --no-install-recommends gh

# ── Node.js LTS (NodeSource) ──────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y --no-install-recommends nodejs
npm install -g npm@latest

# ── Neovim ───────────────────────────────────────────────────────────────────
# Asset names don't include version — use /releases/latest/download/ directly.
if [[ "$ARCH" == "arm64" ]]; then
    NVIM_ASSET="nvim-linux-arm64.tar.gz"
    NVIM_DIR="nvim-linux-arm64"
else
    NVIM_ASSET="nvim-linux-x86_64.tar.gz"
    NVIM_DIR="nvim-linux-x86_64"
fi
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}" \
    | tar xz -C /opt
ln -sf "/opt/${NVIM_DIR}/bin/nvim" /usr/local/bin/nvim

# ── Starship ──────────────────────────────────────────────────────────────────
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

# ── Eza ───────────────────────────────────────────────────────────────────────
# Use gierens apt repo — official Debian install method per eza README.
# Avoids GitHub release asset naming inconsistencies; supports amd64 + arm64.
mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    > /etc/apt/sources.list.d/gierens.list
chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
apt-get update -qq
apt-get install -y --no-install-recommends eza

# ── Fzf ──────────────────────────────────────────────────────────────────────
# apt's fzf is 0.38 (too old for `fzf --fish`; needs ≥0.48). Install from GitHub.
FZF_TAG="$(gh_tag junegunn/fzf)"; echo "fzf ${FZF_TAG}"
FZF_VER="${FZF_TAG#v}"
if [[ "$ARCH" == "arm64" ]]; then
    FZF_ASSET="fzf-${FZF_VER}-linux_arm64.tar.gz"
else
    FZF_ASSET="fzf-${FZF_VER}-linux_amd64.tar.gz"
fi
FZF_DIR=$(mktemp -d)
curl -fsSL "https://github.com/junegunn/fzf/releases/download/${FZF_TAG}/${FZF_ASSET}" \
    | tar xz -C "$FZF_DIR"
find "$FZF_DIR" -name 'fzf' -type f -exec install -m 755 {} /usr/local/bin/fzf \;
rm -rf "$FZF_DIR"

# ── Zoxide ────────────────────────────────────────────────────────────────────
ZO_TAG="$(gh_tag ajeetdsouza/zoxide)"; echo "zoxide ${ZO_TAG}"
ZO_VER="${ZO_TAG#v}"  # zoxide asset filenames have no v-prefix (e.g. zoxide-0.9.9-...)
if [[ "$ARCH" == "arm64" ]]; then
    ZO_ASSET="zoxide-${ZO_VER}-aarch64-unknown-linux-musl.tar.gz"
else
    ZO_ASSET="zoxide-${ZO_VER}-x86_64-unknown-linux-musl.tar.gz"
fi
ZO_DIR=$(mktemp -d)
curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/${ZO_TAG}/${ZO_ASSET}" \
    | tar xz -C "$ZO_DIR"
find "$ZO_DIR" -name 'zoxide' -type f -exec install -m 755 {} /usr/local/bin/zoxide \;
rm -rf "$ZO_DIR"

# ── Atuin ─────────────────────────────────────────────────────────────────────
ATUIN_TAG="$(gh_tag atuinsh/atuin)"; echo "atuin ${ATUIN_TAG}"
if [[ "$ARCH" == "arm64" ]]; then
    ATUIN_ASSET="atuin-aarch64-unknown-linux-musl.tar.gz"
else
    ATUIN_ASSET="atuin-x86_64-unknown-linux-musl.tar.gz"
fi
ATUIN_DIR=$(mktemp -d)
curl -fsSL "https://github.com/atuinsh/atuin/releases/download/${ATUIN_TAG}/${ATUIN_ASSET}" \
    | tar xz -C "$ATUIN_DIR" --strip-components=1
find "$ATUIN_DIR" -name 'atuin' -type f -exec install -m 755 {} /usr/local/bin/atuin \;
rm -rf "$ATUIN_DIR"

# ── Mise ──────────────────────────────────────────────────────────────────────
curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# ── Git-delta ─────────────────────────────────────────────────────────────────
DELTA_TAG="$(gh_tag dandavison/delta)"; echo "delta ${DELTA_TAG}"
DELTA_VER="${DELTA_TAG#v}"
if [[ "$ARCH" == "arm64" ]]; then
    DELTA_ASSET="git-delta_${DELTA_VER}_arm64.deb"
else
    DELTA_ASSET="git-delta_${DELTA_VER}_amd64.deb"
fi
DELTA_DEB=$(mktemp --suffix=.deb)
curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/${DELTA_ASSET}" \
    -o "$DELTA_DEB"
dpkg -i "$DELTA_DEB" && rm "$DELTA_DEB"

# ── Lazygit ───────────────────────────────────────────────────────────────────
LG_TAG="$(gh_tag jesseduffield/lazygit)"; echo "lazygit ${LG_TAG}"
LG_VER="${LG_TAG#v}"
if [[ "$ARCH" == "arm64" ]]; then
    LG_ASSET="lazygit_${LG_VER}_Linux_arm64.tar.gz"
else
    LG_ASSET="lazygit_${LG_VER}_Linux_x86_64.tar.gz"
fi
LG_DIR=$(mktemp -d)
curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${LG_TAG}/${LG_ASSET}" \
    | tar xz -C "$LG_DIR"
find "$LG_DIR" -name 'lazygit' -type f -exec install -m 755 {} /usr/local/bin/lazygit \;
rm -rf "$LG_DIR"

# ── Jujutsu (jj) ─────────────────────────────────────────────────────────────
JJ_TAG="$(gh_tag jj-vcs/jj)"; echo "jj ${JJ_TAG}"
if [[ "$ARCH" == "arm64" ]]; then
    JJ_ASSET="jj-${JJ_TAG}-aarch64-unknown-linux-musl.tar.gz"
else
    JJ_ASSET="jj-${JJ_TAG}-x86_64-unknown-linux-musl.tar.gz"
fi
JJ_DIR=$(mktemp -d)
curl -fsSL "https://github.com/jj-vcs/jj/releases/download/${JJ_TAG}/${JJ_ASSET}" \
    | tar xz -C "$JJ_DIR"
find "$JJ_DIR" -name 'jj' -type f -exec install -m 755 {} /usr/local/bin/jj \;
rm -rf "$JJ_DIR"

# ── Yq ────────────────────────────────────────────────────────────────────────
# Asset names don't include version — use /releases/latest/download/ directly.
if [[ "$ARCH" == "arm64" ]]; then
    YQ_BIN="yq_linux_arm64"
else
    YQ_BIN="yq_linux_amd64"
fi
curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/${YQ_BIN}" \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# ── Shfmt ─────────────────────────────────────────────────────────────────────
SHFMT_TAG="$(gh_tag mvdan/sh)"; echo "shfmt ${SHFMT_TAG}"
if [[ "$ARCH" == "arm64" ]]; then
    SHFMT_BIN="shfmt_${SHFMT_TAG}_linux_arm64"
else
    SHFMT_BIN="shfmt_${SHFMT_TAG}_linux_amd64"
fi
curl -fsSL "https://github.com/mvdan/sh/releases/download/${SHFMT_TAG}/${SHFMT_BIN}" \
    -o /usr/local/bin/shfmt && chmod +x /usr/local/bin/shfmt

# ── Pnpm ─────────────────────────────────────────────────────────────────────
npm install -g pnpm

# ── Cleanup ───────────────────────────────────────────────────────────────────
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
