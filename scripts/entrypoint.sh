#!/usr/bin/env bash
# Start sshd (needs root; devcontainers base image gives vscode passwordless sudo),
# then hand off to fish as the interactive login shell.
sudo /usr/sbin/sshd

exec /usr/bin/fish --login
