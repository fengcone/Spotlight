#!/bin/bash

echo "🔨 Building Spotlight..."

# 检查是否安装了 Xcode
if ! xcode-select -p &> /dev/null; then
    echo "❌ Error: Xcode is not installed or not selected."
    echo "Please install Xcode and run: sudo xcode-select --switch /Applications/Xcode.app"
    exit 1
fi

# 源文件
SOURCES=(
    "Sources/main.swift"
    "Sources/AppDelegate.swift"
    "Sources/ConfigManager.swift"
    "Sources/GlobalHotKeyMonitor.swift"
    "Sources/SearchWindow.swift"
    "Sources/SearchEngine.swift"
    "Sources/SettingsView.swift"
    "Sources/Logger.swift"
    "Sources/UsageHistory.swift"
    "Sources/DictionaryService.swift"
)

# 输出目录
OUTPUT_DIR=".build"
mkdir -p "$OUTPUT_DIR"

# 编译
echo "Compiling sources..."
swiftc -o "$OUTPUT_DIR/Spotlight" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -import-objc-header <(echo "") \
    "${SOURCES[@]}"

# 如果有 entitlements 文件，使用 codesign 签名
if [ -f "Spotlight.entitlements" ]; then
    echo "Applying entitlements..."
    codesign --entitlements Spotlight.entitlements -s - "$OUTPUT_DIR/Spotlight" 2>/dev/null || true
fi

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📦 Binary location: $OUTPUT_DIR/Spotlight"
    echo ""
    echo "To run the application:"
    echo "  $OUTPUT_DIR/Spotlight"
    echo ""
    echo "⚠️  First run requires:"
    echo "  - Accessibility permissions (System Settings → Privacy & Security → Accessibility)"
    echo "  - Full Disk Access (optional, for browser history)"
else
    echo "❌ Build failed!"
    exit 1
fi
