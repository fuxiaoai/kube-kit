#!/usr/bin/env bash

set -euo pipefail

REPO_OWNER="${KK_GITHUB_OWNER:-fuxiaoai}"
REPO_NAME="${KK_GITHUB_REPO:-kube-kit}"
REPO_REF="${KK_GITHUB_REF:-main}"
REPO_TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REPO_REF}.tar.gz"
FZF_VERSION="${KK_FZF_VERSION:-0.46.1}"

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' is not installed." >&2
        exit 1
    fi
}

pick_install_dir() {
    local existing_kk
    existing_kk=$(command -v kk 2>/dev/null || true)

    if [[ -n "${KK_INSTALL_DIR:-}" ]]; then
        INSTALL_DIR="$KK_INSTALL_DIR"
        TARGET_KK_PATH="${INSTALL_DIR}/kk"
        echo "Using custom install dir from KK_INSTALL_DIR: ${INSTALL_DIR}"
        return
    fi

    if [[ -n "$existing_kk" && -x "$existing_kk" ]]; then
        INSTALL_DIR=$(cd -P "$(dirname "$existing_kk")" && pwd)
        TARGET_KK_PATH="${INSTALL_DIR}/kk"
        echo "Existing kk detected at ${existing_kk}, upgrading in place."
        return
    fi

    INSTALL_DIR="${HOME}/.local/bin"
    TARGET_KK_PATH="${INSTALL_DIR}/kk"
    echo "No existing kk detected, installing to ${TARGET_KK_PATH}."
}

install_fzf_if_missing() {
    local archive_path=""
    local asset_name=""
    local os_name
    local arch_name

    if command -v fzf >/dev/null 2>&1; then
        echo "fzf already exists at $(command -v fzf), skipping bundled install."
        return
    fi

    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch_name=$(uname -m)

    case "${os_name}:${arch_name}" in
        linux:x86_64|linux:amd64)
            asset_name="fzf-${FZF_VERSION}-linux_amd64.tar.gz"
            archive_path="${TMP_DIR}/fzf.tar.gz"
            ;;
        linux:aarch64|linux:arm64)
            asset_name="fzf-${FZF_VERSION}-linux_arm64.tar.gz"
            archive_path="${TMP_DIR}/fzf.tar.gz"
            ;;
        darwin:x86_64|darwin:amd64)
            asset_name="fzf-${FZF_VERSION}-darwin_amd64.zip"
            archive_path="${TMP_DIR}/fzf.zip"
            ;;
        darwin:arm64|darwin:aarch64)
            asset_name="fzf-${FZF_VERSION}-darwin_arm64.zip"
            archive_path="${TMP_DIR}/fzf.zip"
            ;;
        *)
            echo "Warning: unsupported platform ${os_name}/${arch_name}, please install fzf manually." >&2
            return
            ;;
    esac

    echo "fzf is missing, downloading ${asset_name}..."
    if ! curl -fsSL "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/${asset_name}" -o "${archive_path}"; then
        echo "Warning: failed to download fzf. Please install fzf manually if 'kk' cannot start." >&2
        return
    fi

    rm -f "${TMP_DIR}/fzf"
    case "${archive_path}" in
        *.tar.gz)
            tar -xzf "${archive_path}" -C "${TMP_DIR}"
            ;;
        *.zip)
            require_cmd unzip
            unzip -p "${archive_path}" fzf > "${TMP_DIR}/fzf"
            ;;
    esac

    if [[ ! -f "${TMP_DIR}/fzf" ]]; then
        echo "Warning: fzf binary was not found in downloaded archive." >&2
        return
    fi

    cp "${TMP_DIR}/fzf" "${INSTALL_DIR}/fzf"
    chmod +x "${INSTALL_DIR}/fzf"
    echo "fzf installed to ${INSTALL_DIR}/fzf"
}

echo "======================================"
echo "    Installing kube-kit (kk)          "
echo "======================================"

require_cmd bash
require_cmd curl
require_cmd tar

TMP_DIR=$(mktemp -d -t kube-kit-install-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

pick_install_dir

echo "Downloading kube-kit from ${REPO_TARBALL_URL}..."
curl -fsSL "${REPO_TARBALL_URL}" -o "${TMP_DIR}/kube-kit.tar.gz"
tar -xzf "${TMP_DIR}/kube-kit.tar.gz" -C "${TMP_DIR}"

SRC_DIR=$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)
if [[ -z "${SRC_DIR}" ]]; then
    echo "Error: failed to locate extracted kube-kit source directory." >&2
    exit 1
fi

mkdir -p "${INSTALL_DIR}"
cp "${SRC_DIR}/kk" "${TARGET_KK_PATH}"
rm -rf "${INSTALL_DIR}/lib"
cp -R "${SRC_DIR}/lib" "${INSTALL_DIR}/lib"
chmod +x "${TARGET_KK_PATH}"

install_fzf_if_missing

hash -r 2>/dev/null || true

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "Warning: ${INSTALL_DIR} is not in your PATH."
    echo "Add the following line to your shell profile if needed:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
fi

echo "======================================"
echo "kube-kit installed successfully!"
echo "kk path: ${TARGET_KK_PATH}"
echo "Run 'kk' to get started."
echo "======================================"