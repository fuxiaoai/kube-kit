#!/usr/bin/env bash

set -e

echo "Installing kube-kit..."

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

cp -r ./* "${INSTALL_DIR}/"

if ! echo "$PATH" | grep -q "${HOME}/.local/bin"; then
    echo "Warning: ${HOME}/.local/bin is not in your PATH. Please add it to your ~/.bashrc or ~/.zshrc."
fi

echo "kube-kit installed successfully. You can run 'kk' to start."
