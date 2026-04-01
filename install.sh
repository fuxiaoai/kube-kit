#!/usr/bin/env bash

set -e

# Default installation directory
INSTALL_DIR="${HOME}/.local/bin"

echo "======================================"
echo "    Installing kube-kit (kk)          "
echo "======================================"

# Ensure Git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is required to install kube-kit."
    exit 1
fi

# Define the repository URL
REPO_URL="https://github.com/fuxiaoai/kube-kit.git"

# Create a temporary directory
TMP_DIR=$(mktemp -d -t kube-kit-install-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning kube-kit from $REPO_URL..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR"

echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copy files, excluding Git directories
cp "$TMP_DIR/kk" "$INSTALL_DIR/"
cp -r "$TMP_DIR/lib" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/kk"

if ! echo "$PATH" | grep -q "${HOME}/.local/bin"; then
    echo ""
    echo "⚠️  Warning: ${HOME}/.local/bin is not in your PATH."
    echo "   Please add it to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "======================================"
echo "✅ kube-kit installed successfully!"
echo "   Run 'kk' to get started."
echo "======================================"
