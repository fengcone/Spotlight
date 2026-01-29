#!/bin/bash

# =============================================================================
# Spotlight 权限和签名检查脚本
# =============================================================================

APP_PATH="$HOME/Applications/Spotlight.app"
BUNDLE_ID="com.custom.spotlight"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Spotlight 权限检查${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 检查应用是否存在
echo -e "${BLUE}[1/7] 应用位置${NC}"
if [ -d "$APP_PATH" ]; then
    echo -e "   ${GREEN}✅${NC} 应用存在: $APP_PATH"
else
    echo -e "   ${RED}❌${NC} 应用不存在: $APP_PATH"
    echo "   请先运行: cp -r .build/Spotlight.app ~/Applications/"
    exit 1
fi
echo ""

# 2. 检查代码签名
echo -e "${BLUE}[2/7] 代码签名${NC}"
codesign -dv "$APP_PATH" 2>&1 | grep -E "(Identifier|Format|Signature|TeamIdentifier|Authority)" | while read line; do
    if echo "$line" | grep -q "Format=app bundle with"; then
        echo "   📦 $line"
    elif echo "$line" | grep -q "Identifier="; then
        echo "   🏷️  $line"
    elif echo "$line" | grep -q "Signature="; then
        if echo "$line" | grep -q "adhoc"; then
            echo -e "   ${YELLOW}⚠️  $line${NC} (临时签名，可能导致权限问题)"
        else
            echo -e "   ${GREEN}✅${NC} $line"
        fi
    elif echo "$line" | grep -q "TeamIdentifier="; then
        echo "   👥 $line"
    else
        echo "   🔐 $line"
    fi
done
echo ""

# 3. 检查 Info.plist
echo -e "${BLUE}[3/7] Info.plist${NC}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    CF_BUNDLE_ID=$(plutil -p "$INFO_PLIST" | grep CFBundleIdentifier | cut -d'"' -f4)
    CF_BUNDLE_NAME=$(plutil -p "$INFO_PLIST" | grep CFBundleName | cut -d'"' -f4)
    echo "   Bundle ID: $CF_BUNDLE_ID"
    echo "   App Name: $CF_BUNDLE_NAME"
else
    echo -e "   ${RED}❌${NC} Info.plist 不存在"
fi
echo ""

# 4. 检查 Entitlements
echo -e "${BLUE}[4/7] Entitlements${NC}"
ENTITLEMENTS="$APP_PATH/Contents/Spotlight.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo "   文件存在"
    if grep -q "com.apple.security.automation.apple-events" "$ENTITLEMENTS"; then
        echo -e "   ${GREEN}✅${NC} Apple Events 权限已声明"
    else
        echo -e "   ${YELLOW}⚠️${NC} Apple Events 权限未声明"
    fi
    codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -E "(automation|apple-events)" | while read line; do
        echo "   → $line"
    done
else
    echo -e "   ${YELLOW}⚠️${NC} Entitlements 文件不存在"
fi
echo ""

# 5. 检查辅助功能权限
echo -e "${BLUE}[5/7] 辅助功能权限${NC}"
ACC_CHECK=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='$BUNDLE_ID'" 2>/dev/null)
if [ -n "$ACC_CHECK" ]; then
    case $ACC_CHECK in
        0) echo -e "   ${RED}❌${NC} 未授权";;
        2) echo -e "   ${GREEN}✅${NC} 已授权";;
        *) echo "   状态码: $ACC_CHECK";;
    esac
else
    echo -e "   ${YELLOW}⚠️${NC} 未找到记录 (可能未授予)"
fi
echo ""

# 6. 检查 Apple Events 权限
echo -e "${BLUE}[6/7] Apple Events 自动化权限${NC}"
AE_CHECK=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT auth_value FROM access WHERE service='kTCCServiceAppleEvents' AND client='$BUNDLE_ID'" 2>/dev/null)
if [ -n "$AE_CHECK" ]; then
    case $AE_CHECK in
        0) echo -e "   ${RED}❌${NC} 未授权";;
        2) echo -e "   ${GREEN}✅${NC} 已授权";;
        *) echo "   状态码: $AE_CHECK";;
    esac
else
    echo -e "   ${YELLOW}⚠️${NC} 未找到记录 (可能未授予)"
    echo "   需要在系统设置中手动授予"
fi
echo ""

# 7. 测试 AppleScript 访问 Chrome
echo -e "${BLUE}[7/7] Chrome AppleScript 测试${NC}"
CHROME_RUNNING=$(osascript -e 'tell application "System Events" to get name of processes' 2>/dev/null | grep -c "Google Chrome" || echo "0")
if [ "$CHROME_RUNNING" -gt 0 ]; then
    echo -e "   ${GREEN}✅${NC} Chrome 正在运行"
    echo "   测试 AppleScript 访问..."
    RESULT=$(osascript -e 'tell application id "com.google.Chrome" to get URL of every tab of every window' 2>&1)
    if [ $? -eq 0 ]; then
        TAB_COUNT=$(echo "$RESULT" | grep -c "https" || echo "0")
        echo -e "   ${GREEN}✅${NC} AppleScript 访问成功 (找到 $TAB_COUNT 个标签)"
    else
        echo -e "   ${RED}❌${NC} AppleScript 访问失败: $RESULT"
    fi
else
    echo -e "   ${YELLOW}⚠️${NC} Chrome 未运行，无法测试"
fi
echo ""

# 总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}总结${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "如果权限未授予，请："
echo "  1. 系统设置 → 隐私与安全性 → 辅助功能 → 添加 Spotlight"
echo "  2. 系统设置 → 隐私与安全性 → 自动化 → 勾选 Google Chrome"
echo ""
echo "如果权限已授予但仍不工作，尝试："
echo "  killall Spotlight"
echo "  killall 'Google Chrome'"
echo "  open ~/Applications/Spotlight.app"
echo ""
