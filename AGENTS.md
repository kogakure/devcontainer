# AGENTS.md

This file provides guidance to agentic agents when working with code in this repository.

## What this repo is

"Floating Phoenix" — a public, secret-free Docker devcontainer image
(`ghcr.io/kogakure/devcontainer`) bundling Fish + Starship + AI coding agents
(Claude Code, Codex, OpenCode, Pi Agent, Grok) plus a full CLI toolset. There
is no application code here — this is infrastructure: a Dockerfile, shell
provisioning scripts, and devcontainer/compose configs. There is no test
suite, linter, or package.json to run.

## Build & verify commands

```sh
# Build the image locally
docker build -t devcontainer .

# Verify no secrets leaked into the image
docker run --rm devcontainer sh -c \
  'find /home/vscode -name auth.json -o -name "*.asc" 2>/dev/null; echo done'

# Verify agents/tools are on PATH
docker run --rm devcontainer fish -c \
  'claude --version; codex --version; lazygit --version; starship --version; eza --version'

# Run the container standalone (Zed / headless / docker-run attach flow)
docker compose up -d
docker compose exec dev fish
docker compose down

# devcontainer CLI (VS Code/Cursor-style, from any project dir with the json copied in)
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . fish
```

Shell scripts under `scripts/` should stay `shellcheck`-clean (shellcheck is
installed in the image and used by contributors editing these scripts).

## Architecture: three-layer build + runtime credential binding

`Dockerfile` builds in three distinct layers — order matters, don't collapse them:

1. **Layer 1 (root)**: `scripts/install-tools.sh` — apt packages + direct
   GitHub-release binary installs (ripgrep, fd, bat, fzf, zoxide, atuin,
   delta, lazygit, jj, eza, starship, neovim, mise, gh, node/pnpm). Most
   non-apt tools are fetched via `gh_tag()`, which resolves `latest` by
   following the GitHub `/releases/latest` redirect (avoids API rate limits).
   Prefer this release-URL pattern over adding new apt sources when adding
   tools.
2. **Layer 2 (vscode user)**: `scripts/install-agents.sh` — installs the AI
   agent CLIs into user-local npm/paths (`~/.local/bin`,
   `~/.local/pi-agent-npm`, `~/.grok/bin`). Each agent's auth is deliberately
   _not_ baked in — comments in the script note which runtime bind-mount
   supplies credentials for each agent.
3. **Layer 3 (vscode user)**: `scripts/bootstrap-dotfiles.sh` — shallow-clones
   the _public_ `kogakure/dotfiles` repo (`--no-recurse-submodules`, so no
   private vault content ever enters the image), symlinks a Linux-portable
   subset of `config/`, skips macOS-only dirs (`karabiner`, `aerospace`,
   `borders`, `ghostty`, `wezterm`, `warp`), and stubs out mount targets
   (`~/.claude`, `~/.codex`, `~/.pi/agent`, `~/.grok`, `~/.config/gh`,
   `~/.agents`, git identity includes) so the container doesn't error before
   runtime mounts land. GPG signing is disabled globally in-image
   (`commit.gpgsign=false`) since the private key never enters the container.

**The core design invariant**: the image itself must never contain secrets.
All credentials (Claude OAuth, Codex auth, Pi Agent auth, Grok auth, `gh`
auth, git identity, private agent prompts) reach the running container only
via read-only bind mounts defined in `.devcontainer/devcontainer.json`
(`mounts` array) and mirrored in `compose.yaml` (`volumes`). When adding a
new agent or credential-consuming tool, add its mount to _both_ files, keep
it `readonly`, and have `bootstrap-dotfiles.sh` create the mount-target
directory/stub file so a missing host credential doesn't break login shells.
SSH agent forwarding (`SSH_AUTH_SOCK`) follows the same runtime-injection
principle — works with Secretive on macOS without ever copying a key into
the container.

CI enforces the no-secrets invariant: `.github/workflows/build.yml` runs a
`security-gate` job before every build/push that fails the workflow if
`auth.json`, `*.asc`, `private_keys*`, `private/`, `.secrets`, or `*.env`
appear anywhere in the build context.

## Two parallel entry paths

- **VS Code / Cursor**: use `.devcontainer/devcontainer.json` directly
  ("Reopen in Container"). This is the primary, documented path.
- **Zed / headless / plain Docker**: use `compose.yaml` or a raw `docker run`
  with the same set of `-v ...:ro` mounts (see README "CLI / SSH" section).
  `compose.yaml`'s header comment explicitly says VS Code/Cursor users should
  _not_ use it — keep both files' mount lists in sync when changing
  credential wiring, but don't merge them into one mechanism.

`devcontainer.json` currently points at the published `image:` (not
`build:`) — the commented-out `"build": { "dockerfile": "../Dockerfile" }`
line is intentionally left as a toggle for local-build testing before a CI
image publish. When testing unreleased Dockerfile changes end-to-end, expect
to flip `image:`→`build:` temporarily and flip back before merging (this
repo's convention: commit the local-build toggle only as a temporary
intermediate commit, then revert to `image:` once CI has published the new
tag).

## CI/release flow

`.github/workflows/build.yml`: `security-gate` → `build` (matrix:
linux/amd64 on `ubuntu-latest`, linux/arm64 on `ubuntu-24.04-arm`, native
runners not QEMU) → `merge` (multi-arch manifest, GHA cache scoped per
platform). Runs on push to `main`, on tags `v*`, and on PRs (build-only, no
push). Publishes to `ghcr.io/kogakure/devcontainer`; make the package public
manually via GitHub → Packages → Package settings after first publish.

## Customization conventions

- New apt/binary tool → append to `scripts/install-tools.sh`, following the
  existing `gh_tag()` + arch-conditional asset-name pattern for GitHub
  release binaries.
- New agent CLI → add install step to `scripts/install-agents.sh` (user
  layer), then wire its credential path into both
  `.devcontainer/devcontainer.json` (`mounts`) and `compose.yaml`
  (`volumes`), and add a stub/mkdir for it in `bootstrap-dotfiles.sh`.
- Pin agent versions with e.g. `npm install -g @anthropic-ai/claude-code@x.y.z`
  in `install-agents.sh` rather than floating `latest`.
- Downstream private customization is expected to happen in a _separate_
  repo via `FROM ghcr.io/kogakure/devcontainer:latest`, not by adding private
  content here.
