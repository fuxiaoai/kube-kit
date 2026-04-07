#!/usr/bin/env bash
#
# 该脚本用于将 kube-kit 和 fzf 的依赖打包生成一个**完全独立**的安装脚本。
# 你可以把生成的 standalone_install.sh 直接复制粘贴到 Snippet，
# 别人只要能在目标机器上 curl 拿到该脚本并用 bash 执行，即可一键闭环完成所有安装。

set -e

# ================================
# 1. 预备环境与依赖下载
# ================================
TMP_DIR=$(mktemp -d -t kk-builder-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "👉 Using local kube-kit.tar.gz..."
if [ ! -f "kube-kit.tar.gz" ]; then
    echo "❌ kube-kit.tar.gz not found! Please run 'make package' first."
    exit 1
fi
cp "kube-kit.tar.gz" "$TMP_DIR/kube-kit.tar.gz"

echo "👉 Fetching fzf binary (Linux amd64)..."
FZF_URL="https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-linux_amd64.tar.gz"
curl -sL "$FZF_URL" -o "$TMP_DIR/fzf.tar.gz"

# ================================
# 2. 对文件进行 Base64 编码打包
# ================================
echo "👉 Encoding payloads to Base64..."
KK_B64=$(cat "$TMP_DIR/kube-kit.tar.gz" | base64 | tr -d '\n')
FZF_B64=$(cat "$TMP_DIR/fzf.tar.gz" | base64 | tr -d '\n')

# ================================
# 3. 组装独立的 Bash 脚本
# ================================
OUT_FILE="standalone_install.sh"
echo "👉 Assembling standalone installer: $OUT_FILE..."

cat <<EOF > "$OUT_FILE"
#!/usr/bin/env bash

# ==============================================================================
# kube-kit (kk) 自包含安装脚本
# 该脚本内嵌了 kube-kit 和 fzf 依赖的压缩包，无需在目标环境联网下载任何依赖。
# 适用于强隔离的纯内网环境（如 E20/E44 隔离集群）。
#
# 使用方式: 
#   curl -sL "你的Snippet地址" | bash
# ==============================================================================

set -e

echo "======================================"
echo "    kube-kit Standalone Installer     "
echo "======================================"

# 创建运行时临时目录
TMP_DIR=\$(mktemp -d -t kk-install-XXXXXX)
trap 'rm -rf "\$TMP_DIR"' EXIT

DEFAULT_INSTALL_DIR="/usr/local/bin"
EXISTING_KK_PATH=\$(command -v kk 2>/dev/null || true)

if [ -n "\$EXISTING_KK_PATH" ]; then
    TARGET_KK_PATH=\$(readlink -f "\$EXISTING_KK_PATH" 2>/dev/null || printf '%s\n' "\$EXISTING_KK_PATH")
    INSTALL_DIR=\$(dirname "\$TARGET_KK_PATH")
    echo "👉 Existing kk detected at \$EXISTING_KK_PATH, updating resolved target \$TARGET_KK_PATH"
else
    INSTALL_DIR="\$DEFAULT_INSTALL_DIR"
    TARGET_KK_PATH="\$INSTALL_DIR/kk"
    echo "👉 No existing kk detected, installing to default path \$TARGET_KK_PATH"
fi

export PATH="\$INSTALL_DIR:/usr/bin:/bin:\$PATH"
mkdir -p "\$INSTALL_DIR"

echo "👉 Extracting and installing fzf dependency..."
echo "$FZF_B64" | base64 -d > "\$TMP_DIR/fzf.tar.gz"
tar -xzf "\$TMP_DIR/fzf.tar.gz" -C "\$TMP_DIR"
rm -f "\$INSTALL_DIR/fzf" || true
cp "\$TMP_DIR/fzf" "\$INSTALL_DIR/fzf"
chmod +x "\$INSTALL_DIR/fzf"
echo "✅ fzf installed to \$INSTALL_DIR/fzf"

echo "👉 Extracting and installing kube-kit..."
echo "$KK_B64" | base64 -d > "\$TMP_DIR/kube-kit.tar.gz"
tar -xzf "\$TMP_DIR/kube-kit.tar.gz" -C "\$TMP_DIR"

rm -f "\$TARGET_KK_PATH" || true
cp "\$TMP_DIR/kk" "\$TARGET_KK_PATH"
mkdir -p "\$INSTALL_DIR/lib"
for lib_file in "\$TMP_DIR"/lib/*; do
    [ -e "\$lib_file" ] || continue
    cp -R "\$lib_file" "\$INSTALL_DIR/lib/"
done
chmod +x "\$TARGET_KK_PATH"
hash -r 2>/dev/null || true
echo "✅ kube-kit installed to \$TARGET_KK_PATH"
echo "✅ Current 'kk' command resolves to: \$(command -v kk 2>/dev/null || printf '%s\n' "\$TARGET_KK_PATH")"

echo "======================================"
echo "🎉 All Done! Installation successful!"
echo "   You can now run 'kk' anywhere in this terminal."
echo "======================================"
EOF

chmod +x "$OUT_FILE"

echo ""
echo "✅ 独立安装包生成完毕: $OUT_FILE"
echo "📂 文件大小: $(du -h $OUT_FILE | awk '{print $1}')"
echo "💡 请将 $OUT_FILE 的全部内容粘贴到你的 Code 平台 Snippet 中！"
