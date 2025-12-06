#!/bin/bash
#
# 权限诊断脚本
# 用于检测 Spotlight.app 是否有完全磁盘访问权限
#

set -e

echo "🔍 Spotlight 权限诊断工具"
echo "================================"
echo ""

# 检查应用是否存在
APP_PATH="$HOME/Applications/Spotlight.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="/Applications/Spotlight.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 找不到 Spotlight.app"
    echo "   请先运行 ./package.sh 并安装应用"
    exit 1
fi

echo "📦 应用路径: $APP_PATH"
echo ""

# 检查 Chrome 书签文件
BOOKMARKS_PATH="$HOME/Library/Application Support/Google/Chrome/Default/Bookmarks"
HISTORY_PATH="$HOME/Library/Application Support/Google/Chrome/Default/History"

echo "📋 Chrome 数据文件检查:"
echo "-----------------------------------"

if [ -f "$BOOKMARKS_PATH" ]; then
    echo "✅ 书签文件存在: $BOOKMARKS_PATH"
    ls -lh "$BOOKMARKS_PATH" | awk '{print "   大小:", $5, "  权限:", $1}'
else
    echo "❌ 书签文件不存在"
fi

echo ""

if [ -f "$HISTORY_PATH" ]; then
    echo "✅ 历史文件存在: $HISTORY_PATH"
    ls -lh "$HISTORY_PATH" | awk '{print "   大小:", $5, "  权限:", $1}'
else
    echo "❌ 历史文件不存在"
fi

echo ""
echo "🔐 权限测试:"
echo "-----------------------------------"

# 测试是否能直接读取（当前用户）
if [ -f "$BOOKMARKS_PATH" ]; then
    if [ -r "$BOOKMARKS_PATH" ]; then
        echo "✅ 当前用户可以读取书签文件"
        head -c 100 "$BOOKMARKS_PATH" > /dev/null 2>&1 && echo "   ✅ 能够读取文件内容" || echo "   ❌ 无法读取文件内容"
    else
        echo "❌ 当前用户无法读取书签文件"
    fi
fi

echo ""
echo "📱 应用签名检查:"
echo "-----------------------------------"

# 检查应用签名
codesign -dv "$APP_PATH" 2>&1 | grep -E "(Identifier|Authority|Signature)" || echo "  无签名信息"

echo ""
echo "🔑 Entitlements 检查:"
echo "-----------------------------------"

# 检查 entitlements
codesign -d --entitlements - "$APP_PATH" 2>&1 | xmllint --format - 2>/dev/null || echo "  无 entitlements"

echo ""
echo "🎯 完全磁盘访问权限检查:"
echo "-----------------------------------"

# 检查是否在完全磁盘访问列表中
FDA_STATUS=$(sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    "SELECT service, client, allowed FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';" 2>/dev/null || echo "")

if [ -z "$FDA_STATUS" ]; then
    echo "⚠️  无法查询 TCC 数据库（需要 root 权限）"
    echo ""
    echo "💡 请手动检查："
    echo "   系统设置 → 隐私与安全性 → 完全磁盘访问权限"
    echo "   确保 'Spotlight' 在列表中且已开启"
else
    echo "$FDA_STATUS" | grep -i spotlight && echo "✅ Spotlight 在完全磁盘访问列表中" || echo "❌ Spotlight 不在完全磁盘访问列表中"
fi

echo ""
echo "📝 建议操作:"
echo "-----------------------------------"

# 检查应用隔离属性
if xattr -l "$APP_PATH" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo "⚠️  应用有隔离属性（quarantine）"
    echo "   建议执行: xattr -cr '$APP_PATH'"
    echo ""
fi

echo "✅ 确保已授予权限:"
echo "   1. 系统设置 → 隐私与安全性 → 辅助功能 → 添加 Spotlight"
echo "   2. 系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Spotlight"
echo ""
echo "✅ 授权后必须重启应用:"
echo "   killall Spotlight && open '$APP_PATH'"
echo ""

# 查看最新日志
LOG_FILE="$HOME/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log"
if [ -f "$LOG_FILE" ]; then
    echo "📋 最新日志 (最后 10 行):"
    echo "-----------------------------------"
    tail -10 "$LOG_FILE"
    echo ""
    echo "💡 完整日志: $LOG_FILE"
else
    echo "ℹ️  还没有日志文件（应用可能还未运行）"
fi

echo ""
echo "================================"
echo "🎉 诊断完成！"
