#!/usr/bin/env sh
# init-host-mounts.sh — pre-create host-side mount sources for compose.yaml
#
# Run this BEFORE `docker compose up` so that bind-mount file targets exist:
#   sh scripts/init-host-mounts.sh && docker compose up -d
#
# Creates parent directories and stubs any missing credential files so that
# Docker's bind-mount never fails with "bind source path does not exist".
# JSON config files get a valid empty `{}` stub; non-JSON files get empty.
# Real existing files are never touched (guarded by [ -e ]).
#
# Idempotent — safe to run repeatedly.
set -eu

# ── Parent directories ────────────────────────────────────────────────────────
for d in .claude .codex .pi/agent .grok .config/gh .config/git .agents .ssh; do
    mkdir -p "$HOME/$d"
done

# ── JSON credential stubs (empty `{}` avoids parse errors on a 0-byte file) ──
for j in \
    .claude/.credentials.json \
    .claude/settings.json \
    .claude.json \
    .codex/auth.json \
    .pi/agent/auth.json
do
    [ -e "$HOME/$j" ] || printf '{}' > "$HOME/$j"
done

# ── Non-JSON stubs (plain empty file is fine) ─────────────────────────────────
for e in \
    .config/git/config-personal \
    .ssh/authorized_keys
do
    [ -e "$HOME/$e" ] || touch "$HOME/$e"
done

echo "init-host-mounts: done"
