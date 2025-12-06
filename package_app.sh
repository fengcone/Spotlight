#!/bin/bash

# 创建 macOS 应用包

echo "📦 创建 Spotlight.app 应用包..."

# 创建应用目录结构
APP_NAME="Spotlight.app"
APP_PATH="./$APP_NAME"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

# 清理旧的应用包
if [ -d "$APP_PATH" ]; then
    echo "🗑  删除旧的应用包..."
    rm -rf "$APP_PATH"
fi

# 创建目录结构
echo "📁 创建目录结构..."
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# 复制可执行文件
echo "📋 复制可执行文件..."
if [ -f ".build/Spotlight" ]; then
    cp ".build/Spotlight" "$MACOS_PATH/Spotlight"
    chmod +x "$MACOS_PATH/Spotlight"
else
    echo "❌ 错误：找不到 .build/Spotlight，请先运行 ./build.sh"
    exit 1
fi

# 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "$CONTENTS_PATH/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Spotlight</string>
    <key>CFBundleIdentifier</key>
    <string>com.custom.spotlight</string>
    <key>CFBundleName</key>
    <string>Spotlight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ 应用包创建完成！"
echo ""
echo "📦 应用位置: $APP_PATH"
echo ""
echo "🚀 使用方法："
echo "  1. 双击打开: open $APP_PATH"
echo "  2. 或拖到 /Applications 文件夹"
echo "  3. 然后在系统设置中添加此应用的完全磁盘访问权限"
echo ""
