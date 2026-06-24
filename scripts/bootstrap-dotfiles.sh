#!/usr/bin/env bash
# bootstrap-dotfiles.sh — runs as vscode user at Docker build time
# Clones PUBLIC dotfiles repo (no submodules → no private/vault), symlinks
# the Linux-portable subset, installs fish plugins and tmux plugins.
set -euo pipefail

DOTFILES_REPO="https://github.com/kogakure/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# ── Clone (shallow, no submodules) ───────────────────────────────────────────
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    git clone --depth 1 --no-recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# ── Create directory skeleton ────────────────────────────────────────────────
mkdir -p \
    "$HOME/.config" \
    "$HOME/.cache" \
    "$HOME/.local/bin" \
    "$HOME/.local/share" \
    "$HOME/.local/state" \
    "$HOME/.ssh" \
    "$HOME/.tmux/plugins"

chmod 700 "$HOME/.ssh"

# ── Symlink: config/ subset (Linux-portable only) ────────────────────────────
# Mac-only / private dirs excluded:
#   karabiner aerospace borders ghostty wezterm warp
SKIP_CONFIG="karabiner|aerospace|borders|ghostty|wezterm|warp|git|mise"

for src in "$DOTFILES_DIR/config/"*/; do
    name="$(basename "$src")"
    if echo "$name" | grep -qE "^($SKIP_CONFIG)$"; then
        continue
    fi
    target="$HOME/.config/$name"
    ln -sf "$src" "$target"
done

# starship.toml lives directly in config/, not a subdir
if [[ -f "$DOTFILES_DIR/config/starship.toml" ]]; then
    ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
fi

# ── Symlink: root dotfiles (Linux-portable subset) ───────────────────────────
link() { ln -sf "$DOTFILES_DIR/$1" "$HOME/$2"; }

link editorconfig       .editorconfig
link curlrc             .curlrc
link gitmux.conf        .gitmux.conf
link jjconfig.toml      .jjconfig.toml
link session-variables.sh .session-variables.sh

# ── Container-local bash/zsh/profile (NOT linked from dotfiles — Mac versions ──
# contain hardcoded /opt/homebrew paths and fish-only alias syntax that break
# bash inside the container, especially in Zed where the login shell is bash).

# ~/.profile — sourced by login bash and used by Zed for env
cat > "$HOME/.profile" <<'PROFILE_EOF'
# Source session variables (portable, Darwin-guarded)
[ -f "$HOME/.session-variables.sh" ] && . "$HOME/.session-variables.sh"
# Source .bashrc for interactive settings
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
PROFILE_EOF

# ~/.bashrc — portable, no Mac paths
cat > "$HOME/.bashrc" <<'BASHRC_EOF'
# Non-interactive: do nothing
[[ $- == *i* ]] || return

HISTCONTROL=erasedups:ignorespace
HISTFILESIZE=100000
HISTSIZE=10000
HISTTIMEFORMAT="%F %T "
shopt -s histappend checkwinsize extglob globstar

# ── Session variables ────────────────────────────────────────────────────────
[ -f "$HOME/.session-variables.sh" ] && source "$HOME/.session-variables.sh"

# ── Tool initialisations (guarded — no hard-coded paths) ────────────────────
if command -v starship >/dev/null 2>&1 && [[ $TERM != "dumb" ]]; then
    eval "$(starship init bash)"
fi
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash)"
fi
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash 2>/dev/null)" || true
fi
if command -v gh >/dev/null 2>&1; then
    eval "$(gh completion -s bash)"
fi
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# ── Aliases (valid bash syntax) ───────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -p'
alias ls='eza --git --group-directories-first --icons'
alias ll='eza -l --git --group-directories-first --icons'
alias lt='eza --git --group-directories-first --icons --tree'
alias lg='lazygit'
alias v='vim'
if command -v nvim >/dev/null 2>&1; then alias vim='nvim'; fi
alias t='tmux'
alias ta='tmux attach'
alias c='clear'
alias dotfiles='cd $HOME/.dotfiles'
alias reload='exec bash -l'
# AI agents
alias cl='claude --dangerously-skip-permissions'
alias clp='claude --permission-mode plan'
alias clr='claude --resume'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'
alias q='pi --model opencode-go/deepseek-v4-flash -p'
BASHRC_EOF

# ~/.zshrc — portable, no Mac paths, no antidote/brew
cat > "$HOME/.zshrc" <<'ZSHRC_EOF'
autoload -Uz compinit && compinit

CASE_SENSITIVE="true"
DISABLE_AUTO_TITLE="true"

bindkey -v

[ -f "$HOME/.session-variables.sh" ] && source "$HOME/.session-variables.sh"

if command -v starship >/dev/null 2>&1; then eval "$(starship init zsh)"; fi
if command -v direnv >/dev/null 2>&1; then eval "$(direnv hook zsh)"; fi
if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init zsh)"; fi
if command -v atuin >/dev/null 2>&1; then eval "$(atuin init zsh)"; fi
if command -v fzf >/dev/null 2>&1; then source <(fzf --zsh 2>/dev/null) || true; fi
if command -v gh >/dev/null 2>&1; then eval "$(gh completion -s zsh)"; fi
if command -v mise >/dev/null 2>&1; then eval "$(mise activate zsh)"; fi

alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -p'
alias ls='eza --git --group-directories-first --icons'
alias ll='eza -l --git --group-directories-first --icons'
alias lt='eza --git --group-directories-first --icons --tree'
alias lg='lazygit'
alias v='vim'
if command -v nvim >/dev/null 2>&1; then alias vim='nvim'; fi
alias t='tmux'
alias ta='tmux attach'
alias c='clear'
alias dotfiles='cd $HOME/.dotfiles'
alias reload='exec zsh -l'
alias cl='claude --dangerously-skip-permissions'
alias clp='claude --permission-mode plan'
alias clr='claude --resume'
alias cx='codex --dangerously-bypass-approvals-and-sandbox'
alias q='pi --model opencode-go/deepseek-v4-flash -p'
ZSHRC_EOF

# Skip private/ entries:
#   ~/.agents → private/agents
#   ~/.config/git/config-personal|work → private/git/
#   ~/.wakatime.cfg → private/wakatime.cfg
#   ~/.pi → pi (auth.json is gitignored; mount at runtime)
# Mount targets for runtime secrets:
mkdir -p \
    "$HOME/.claude" \
    "$HOME/.codex" \
    "$HOME/.pi/agent" \
    "$HOME/.grok" \
    "$HOME/.config/gh" \
    "$HOME/.agents"

# Base git config (no identity includes — mounted at runtime)
if [[ -f "$DOTFILES_DIR/config/git/config" ]]; then
    # The base config includes personal/work via includeIf — those files are
    # mounted at runtime. Make the include paths exist so git doesn't error.
    mkdir -p "$HOME/.config/git"
    ln -sf "$DOTFILES_DIR/config/git/config" "$HOME/.config/git/config"
    # Stub include targets (overwritten by runtime mount if provided)
    touch "$HOME/.config/git/config-personal"
    touch "$HOME/.config/git/config-work"
fi

# Disable GPG signing in container (private key lives on host)
git config --global commit.gpgsign false
git config --global tag.gpgsign false

# ── Fish plugins (fisher) ─────────────────────────────────────────────────────
if command -v fish >/dev/null 2>&1 && [[ -f "$DOTFILES_DIR/config/fish/fish_plugins" ]]; then
    # Install fisher itself
    fish -c "
        if not functions -q fisher
            curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
                | source && fisher install jorgebucaran/fisher
        end
    " 2>/dev/null || true

    # Install plugins from fish_plugins manifest
    fish -c "fisher update" 2>/dev/null || true
fi

# ── Tmux plugin manager ───────────────────────────────────────────────────────
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>/dev/null || true
fi

# TPM install (runs headless; plugins defined in tmux.conf)
if [[ -x "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh" ]]; then
    "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh" >/dev/null 2>&1 || true
fi

# ── Mise: container-specific config (no pre-defined tools — avoids GitHub ─────
# rate-limit warnings at every shell startup). mise is still on PATH for
# `mise use -g node@22` etc.; just no @latest tools that fetch remotely.
mkdir -p "$HOME/.config/mise"
cat > "$HOME/.config/mise/config.toml" <<'MISE_EOF'
[settings]
not_found_auto_install = false
idiomatic_version_file_enable_tools = ["ruby", "node"]
MISE_EOF

# ── Atuin init (local DB, no sync — login happens at runtime) ─────────────────
if command -v atuin >/dev/null 2>&1; then
    atuin init --disable-up-arrow 2>/dev/null || true
fi

echo "✓ Dotfiles bootstrap complete"
