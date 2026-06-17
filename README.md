# Floating Phoenix — AI-Agent DevContainer

A public, secret-free Docker image with a complete AI-agent development environment:
Fish shell + Starship + Claude Code, Codex, OpenCode, Pi Agent, Grok — plus the full
CLI toolset from my dotfiles.

Pull the image, point your editor at a project, and every agent is ready to work.
Credentials bind-mount read-only from your host at runtime. Nothing secret is baked
in.

```
ghcr.io/kogakure/devcontainer:latest
```

---

## What's inside

| Category  | Tools                                        |
| --------- | -------------------------------------------- |
| Shell     | Fish 3, Starship, Atuin, Zoxide, Direnv      |
| Editors   | Neovim (LazyVim), tmux                       |
| Search    | ripgrep, fd, bat, fzf, eza, tree             |
| Git       | git-delta, lazygit, jj (jujutsu), gh CLI     |
| Build     | mise, Node.js LTS, pnpm, cmake               |
| Data      | jq, yq, shfmt, shellcheck, universal-ctags   |
| AI agents | Claude Code, Codex, OpenCode, Pi Agent, Grok |

---

## Quick start

### Prerequisites

- Docker Desktop (or OrbStack on macOS)
- One of: VS Code, Cursor, Zed, or the devcontainer CLI

### VS Code / Cursor

1. Open any project folder.
2. Copy `.devcontainer/devcontainer.json` from this repo into that folder (or keep
   your project inside this repo).
3. **VS Code**: `F1` → "Dev Containers: Reopen in Container"
   **Cursor**: same command in the command palette.

Credentials are bind-mounted automatically from your Mac. No re-auth needed.

### Zed

Zed reads `devcontainer.json` directly (Zed ≥ 0.150):

1. Open the project folder in Zed.
2. Zed detects `.devcontainer/devcontainer.json` and offers "Reopen in Container".

Alternatively, use docker compose and attach Zed via SSH:

```sh
docker compose up -d
# Zed → Connect → Remote → localhost:2222  (configure compose.yaml to expose SSH)
```

### CLI / SSH (headless)

```sh
# Install the devcontainer CLI once
npm install -g @devcontainers/cli

# Start container for current project
devcontainer up --workspace-folder .

# Attach a fish shell
devcontainer exec --workspace-folder . fish
```

Or with plain Docker:

```sh
docker run -it --rm \
  -v "$PWD":/workspaces/project \
  -v "$HOME/.claude/.credentials.json":/home/vscode/.claude/.credentials.json:ro \
  -v "$HOME/.codex":/home/vscode/.codex:ro \
  -v "$HOME/.pi/agent/auth.json":/home/vscode/.pi/agent/auth.json:ro \
  -v "$HOME/.grok":/home/vscode/.grok:ro \
  -v "$HOME/.config/gh":/home/vscode/.config/gh:ro \
  -e SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
  ghcr.io/kogakure/devcontainer:latest
```

---

## Secrets — how it works

**Nothing is baked into the image.** All agent credentials reach the container via
read-only bind-mounts defined in `devcontainer.json` / `compose.yaml`:

| Host path                       | Container path | Used by                |
| ------------------------------- | -------------- | ---------------------- |
| `~/.claude/.credentials.json`   | same           | Claude Code OAuth      |
| `~/.claude/settings.json`       | same           | Claude Code settings   |
| `~/.codex/`                     | same           | Codex auth             |
| `~/.pi/agent/auth.json`         | same           | Pi Agent OAuth         |
| `~/.grok/`                      | same           | Grok auth              |
| `~/.config/gh/`                 | same           | GitHub CLI (`gh auth`) |
| `~/.config/git/config-personal` | same           | Git identity           |
| `~/.agents/`                    | same           | Private agent prompts  |

SSH: the devcontainer forwards your host SSH agent socket (`SSH_AUTH_SOCK`), so
Secretive / ssh-agent on macOS works without copying any key.

GPG signing is **disabled inside the container** (`commit.gpgsign = false`). Commits
are made; sign them locally afterwards if needed, or set up GPG agent forwarding
manually.

---

## Building locally

```sh
git clone https://github.com/kogakure/devcontainer.git
cd devcontainer
docker build -t devcontainer .
```

Verify no secrets leaked:

```sh
docker run --rm devcontainer sh -c \
  'find /home/vscode -name auth.json -o -name "*.asc" 2>/dev/null; echo done'
```

Verify agents are on PATH:

```sh
docker run --rm devcontainer fish -c \
  'claude --version; codex --version; lazygit --version; starship --version; eza --version'
```

---

## Customizing

- **More tools**: add `apt-get install` lines to `scripts/install-tools.sh`.
- **Different agent versions**: pin with `npm install -g @anthropic-ai/claude-code@x.y.z`.
- **Your own dotfiles**: change `DOTFILES_REPO` at the top of
  `scripts/bootstrap-dotfiles.sh`. Make sure the repo has Darwin guards in
  `config/fish/config.fish` (see the dotfiles repo README for details).
- **Private extensions**: create a downstream `FROM ghcr.io/kogakure/devcontainer:latest`
  image in a private repo and layer your private `~/.agents` there.

---

## Publishing

The GitHub Action in `.github/workflows/build.yml` builds multi-arch
(`linux/amd64` + `linux/arm64`) and pushes to `ghcr.io/kogakure/devcontainer` on
every push to `main`. A security gate step asserts no `auth.json`, `*.asc`, or
`private/` files are present in the build context before the push proceeds.

Make the package public in **GitHub → Packages → devcontainer → Package settings →
Change visibility → Public**.

---

## Dotfiles Linux-portability changes

The `~/.dotfiles` repo ships macOS-only today. `bootstrap-dotfiles.sh` clones it
without submodules (safe), but the Fish config needs Darwin guards so `brew` and
Secretive paths don't error on startup. These guards are committed to the dotfiles
repo in `config/fish/config.fish` and `session-variables.sh` — see the commit
"feat: add Linux/Darwin portability guards for DevContainer".
