#!/bin/bash

# =============================================================================
# Spotlight 统一构建和打包脚本
# 
# 用法:
#   ./package.sh          # 编译并打包
#   ./package.sh build    # 仅编译
#   ./package.sh package  # 仅打包（需先编译）
#   ./package.sh clean    # 清理构建产物
# =============================================================================

set -e

# 配置
APP_NAME="Spotlight"
BUNDLE_ID="com.custom.spotlight"
VERSION="1.0.0"
BUILD_DIR=".build"
BINARY_PATH="${BUILD_DIR}/Spotlight"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 源文件列表
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
    "Sources/IDEProjectService.swift"
)

# =============================================================================
# 函数定义
# =============================================================================

show_help() {
    echo "Spotlight 构建脚本"
    echo ""
    echo "用法: ./package.sh [命令]"
    echo ""
    echo "命令:"
    echo "  (无参数)    编译并打包应用"
    echo "  build       仅编译可执行文件"
    echo "  package     仅打包应用（需先编译）"
    echo "  clean       清理所有构建产物"
    echo "  help        显示此帮助信息"
    echo ""
    echo "输出目录: ${BUILD_DIR}/"
    echo "  - ${BINARY_PATH}     可执行文件"
    echo "  - ${APP_PATH}        应用包"
}

check_xcode() {
    if ! xcode-select -p &> /dev/null; then
        echo -e "${RED}❌ 错误: Xcode 未安装或未选择${NC}"
        echo "请安装 Xcode 并运行: sudo xcode-select --switch /Applications/Xcode.app"
        exit 1
    fi
}

do_build() {
    echo -e "${BLUE}🔨 编译 Spotlight...${NC}"
    
    check_xcode
    
    # 创建输出目录
    mkdir -p "$BUILD_DIR"
    
    # 编译
    echo "正在编译源文件..."
    swiftc -o "$BINARY_PATH" \
        -framework Cocoa \
        -framework SwiftUI \
        -framework Carbon \
        -import-objc-header <(echo "") \
        "${SOURCES[@]}"
    
    # 应用 entitlements
    if [ -f "Spotlight.entitlements" ]; then
        echo "应用权限配置..."
        codesign --entitlements Spotlight.entitlements -s - "$BINARY_PATH" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ 编译成功!${NC}"
    echo -e "   可执行文件: ${BINARY_PATH}"
}

do_package() {
    echo -e "${BLUE}📦 打包 ${APP_NAME}.app...${NC}"
    
    # 检查可执行文件是否存在
    if [ ! -f "$BINARY_PATH" ]; then
        echo -e "${RED}❌ 错误: 找不到 ${BINARY_PATH}${NC}"
        echo "请先运行: ./package.sh build"
        exit 1
    fi
    
    # 清理旧的应用包
    if [ -d "$APP_PATH" ]; then
        rm -rf "$APP_PATH"
    fi
    
    # 创建目录结构
    CONTENTS_DIR="${APP_PATH}/Contents"
    MACOS_DIR="${CONTENTS_DIR}/MacOS"
    RESOURCES_DIR="${CONTENTS_DIR}/Resources"
    
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"
    
    # 复制可执行文件
    cp "$BINARY_PATH" "$MACOS_DIR/${APP_NAME}"
    chmod +x "$MACOS_DIR/${APP_NAME}"
    
    # 复制配置文件
    if [ -f "ide_config.json" ]; then
        cp "ide_config.json" "$RESOURCES_DIR/"
        echo "   已包含 ide_config.json"
    fi
    
    # 创建 Info.plist
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
</dict>
</plist>
EOF
    
    # 应用 entitlements
    if [ -f "Spotlight.entitlements" ]; then
        cp "Spotlight.entitlements" "${CONTENTS_DIR}/"
        codesign --entitlements "Spotlight.entitlements" --force --sign - "${APP_PATH}" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ 打包成功!${NC}"
    echo ""
    echo -e "📦 应用位置: ${APP_PATH}"
}

do_clean() {
    echo -e "${YELLOW}🗑  清理构建产物...${NC}"
    
    # 清理 .build 目录中的自定义产物
    rm -f "${BINARY_PATH}"
    rm -rf "${APP_PATH}"
    
    # 清理根目录的遗留产物
    rm -f "./Spotlight"
    rm -rf "./Spotlight.app"
    
    echo -e "${GREEN}✅ 清理完成${NC}"
}

show_usage() {
    echo ""
    echo "🚀 使用方法:"
    echo "   运行应用: open ${APP_PATH}"
    echo "   或拖拽到 /Applications 文件夹"
    echo ""
    echo "⚠️  首次运行需要授权:"
    echo "   1. 辅助功能权限 (必需)"
    echo "      系统设置 → 隐私与安全性 → 辅助功能"
    echo ""
    echo "   2. 完全磁盘访问权限 (推荐)"
    echo "      系统设置 → 隐私与安全性 → 完全磁盘访问权限"
}

# =============================================================================
# 主程序
# =============================================================================

case "${1:-}" in
    "build")
        do_build
        ;;
    "package")
        do_package
        ;;
    "clean")
        do_clean
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        # 默认: 编译并打包
        do_build
        echo ""
        do_package
        show_usage
        ;;
    *)
        echo -e "${RED}❌ 未知命令: $1${NC}"
        show_help
        exit 1
        ;;
esac
