#!/bin/bash

# Spotlight 应用打包脚本
# 将编译好的二进制文件打包成 macOS .app 格式

set -e

APP_NAME="Spotlight"
BUNDLE_ID="com.custom.spotlight"
VERSION="1.0.0"
BUILD_DIR=".build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 开始打包 ${APP_NAME}.app..."

# 1. 先编译
echo "🔨 编译应用..."
./build.sh

# 2. 创建 .app 目录结构
echo "📁 创建应用目录结构..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. 复制可执行文件
echo "📋 复制可执行文件..."
cp "${BUILD_DIR}/Spotlight" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 4. 创建 Info.plist
echo "📝 生成 Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Spotlight 需要访问应用程序以实现快速启动功能</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Spotlight 需要访问系统设置以监听全局快捷键</string>
</dict>
</plist>
EOF

# 5. 创建图标（可选）
echo "🎨 创建应用图标..."
# 这里创建一个简单的图标占位符
# 如果你有自定义图标，可以替换这部分
cat > "${RESOURCES_DIR}/AppIcon.iconset/icon_512x512.png" << 'EOF' 2>/dev/null || true
# 图标文件占位符
EOF

# 6. 设置权限
echo "🔐 设置文件权限..."
chmod -R 755 "${APP_DIR}"

# 7. 代码签名（应用 entitlements）
if [ -f "Spotlight.entitlements" ]; then
    echo "✍️  应用权限配置..."
    # 复制 entitlements 到 app 内
    cp "Spotlight.entitlements" "${CONTENTS_DIR}/"
    # 代码签名（使用 ad-hoc 签名）
    codesign --entitlements "Spotlight.entitlements" --force --sign - "${APP_DIR}" 2>/dev/null || {
        echo "⚠️  代码签名失败，但不影响使用"
    }
fi

# 8. 完成
echo ""
echo "✅ 打包完成！"
echo ""
echo "📦 应用位置: ${APP_DIR}"
echo ""
echo "📍 安装方法:"
echo "   方法1: 拖拽到 /Applications 目录"
echo "          cp -r \"${APP_DIR}\" /Applications/"
echo ""
echo "   方法2: 拖拽到 ~/Applications 目录"
echo "          mkdir -p ~/Applications"
echo "          cp -r \"${APP_DIR}\" ~/Applications/"
echo ""
echo "⚠️  首次运行需要授予权限:"
echo "   1. 辅助功能权限 (必需) - 用于监听全局快捷键"
echo "      系统设置 → 隐私与安全性 → 辅助功能 → [+] Spotlight"
echo ""
echo "   2. 完全磁盘访问权限 (强烈推荐) - 用于读取 Chrome 书签和历史"
echo "      系统设置 → 隐私与安全性 → 完全磁盘访问权限 → [+] Spotlight"
echo ""
echo "   ⚠️  如果不授予'完全磁盘访问权限'："
echo "      - ✅ 可以搜索本地应用程序"
echo "      - ❌ 无法读取 Chrome 书签"
echo "      - ❌ 无法读取 Chrome 历史记录"
echo ""
echo "📚 详细权限配置指南请查看: PERMISSIONS.md"
echo ""
echo "🚀 直接运行: open \"${APP_DIR}\""
echo ""
