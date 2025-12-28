# 故障排查指南

## 🔍 常见问题

### 1. 快捷键不响应

#### 症状
按 `Command + Space` 没有反应，窗口不弹出。

#### 原因
- 未授予辅助功能权限
- 与系统 Spotlight 快捷键冲突
- 应用未正确启动

#### 解决方案

**方法 1：检查权限**
```bash
# 查看日志
tail -50 ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log | grep "权限"
```

正常情况应该看到：
```
✅ 辅助功能权限已授予
```

如果看到权限警告：
1. 打开 **系统设置** → **隐私与安全性** → **辅助功能**
2. 添加 Spotlight.app
3. **完全退出应用并重启**

**方法 2：禁用系统 Spotlight**
```bash
# 检查快捷键冲突
# 系统设置 → 键盘 → 键盘快捷键 → Spotlight
# 取消勾选或更改快捷键
```

**方法 3：重启应用**
```bash
# 完全退出
killall Spotlight

# 重新启动
open /Applications/Spotlight.app
```

---

### 2. 无法读取 Chrome 书签/历史

#### 症状
搜索时只能看到应用程序，看不到浏览器书签和历史。

#### 原因
- 未授予完全磁盘访问权限
- Chrome 数据文件不存在
- 文件路径错误

#### 解决方案

**检查权限**
```bash
# 查看日志
grep "Chrome" ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

如果看到 "Permission denied"：
1. 打开 **系统设置** → **隐私与安全性** → **完全磁盘访问权限**
2. 添加 Spotlight.app
3. **完全退出应用并重启**

**检查书签文件**
```bash
# 书签导出文件（需手动导出）
ls ~/Documents/Spotlight/bookmarks_*.html

# 历史数据库
ls ~/Library/Application\ Support/Google/Chrome/Default/History
```

**导出 Chrome 书签**
1. 打开 Chrome
2. 书签 → 书签管理器 → 右上角菜单 → 导出书签
3. 保存到 `~/Documents/Spotlight/bookmarks_YYYY_MM_DD.html`

---

### 3. 输入框无法输入文字

#### 症状
窗口弹出，但无法在输入框中输入。

#### 原因
- 窗口未成为 Key Window
- TextField 未获得焦点
- 事件响应链被中断

#### 解决方案

**方法 1：点击输入框**
用鼠标点击一下输入框，使其获得焦点。

**方法 2：查看日志**
```bash
./Spotlight 2>&1 | grep -i "textfield\|focus\|firstresponder"
```

正常情况应该看到：
```
✅ TextField 已获得焦点
❓ 窗口是否是 Key: true
```

如果看到问题：
```
❌ TextField 未能获得焦点!
❓ 窗口是否是 Key: false
```

尝试重启应用。

---

### 4. 搜索结果为空

#### 症状
输入关键词后没有任何结果。

#### 原因
- 关键词不匹配
- 数据未正确加载
- 过滤器错误使用

#### 解决方案

**检查数据加载**
```bash
grep "加载完成" ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

应该看到：
```
✅ Chrome 书签加载完成，共 X 条记录
✅ 浏览器历史加载完成，共 500 条记录
```

**尝试不同的搜索**
```
# 搜索常见应用
safari
chrome

# 移除魔法后缀
github     # 而不是 github ap
```

**检查搜索日志**
```bash
tail -f ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
# 然后在应用中搜索，观察日志输出
```

---

### 5. 应用无法打开

#### 症状
双击 Spotlight.app 提示"无法验证开发者"或"文件已损坏"。

#### 原因
macOS 的 Gatekeeper 安全机制阻止了未签名的应用。

#### 解决方案

**方法 1：右键打开**
1. 右键点击 Spotlight.app
2. 选择"打开"
3. 在弹出对话框中点击"打开"

**方法 2：移除隔离属性**
```bash
xattr -d com.apple.quarantine /Applications/Spotlight.app
```

**方法 3：允许"任何来源"（不推荐）**
```bash
sudo spctl --master-disable
```

---

### 6. 性能问题（搜索慢、卡顿）

#### 症状
输入后搜索结果返回很慢，或界面卡顿。

#### 原因
- 浏览历史数据过多
- 内存不足
- 其他应用占用资源

#### 解决方案

**限制历史记录**

当前限制为 500 条，如需减少：

编辑 `Sources/SearchEngine.swift`：
```swift
// 将 LIMIT 500 改为更小的值
LIMIT 200
```

**清理缓存**
```bash
# 删除日志文件
rm ~/Library/Logs/Spotlight/*.log

# 清理配置（会重置设置）
rm -rf ~/Library/Application\ Support/Spotlight/
```

**检查性能**
```bash
# 查看搜索耗时日志
grep "搜索耗时" ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

正常情况应该 < 200ms。

---

### 7. 编译错误

#### 错误：SDK 版本不匹配

```
SDK built with Swift 6.1.0
Compiler version Swift 6.1.0 (different build)
```

**解决方案**

使用 Xcode 的 Swift：
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
swift build
```

#### 错误：找不到框架

```
error: cannot find 'Carbon' in scope
```

**解决方案**

确保正确导入：
```swift
import Carbon
import Cocoa
import SwiftUI
```

使用完整编译命令：
```bash
swiftc -o Spotlight Sources/*.swift \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Carbon
```

---

### 8. 快捷键冲突

#### 症状
设置的快捷键不生效，或与其他应用冲突。

#### 解决方案

**更改快捷键**
1. 点击菜单栏图标 → 设置
2. 在快捷键设置中更改
3. 尝试使用 `Option + Space` 或其他组合

**检查系统快捷键**
```
系统设置 → 键盘 → 键盘快捷键
查看并禁用冲突的快捷键
```

---

## 📊 诊断命令

### 全面检查

```bash
#!/bin/bash

echo "=== Spotlight 诊断工具 ==="

# 1. 检查应用是否存在
echo -n "应用文件: "
if [ -f "/Applications/Spotlight.app/Contents/MacOS/Spotlight" ]; then
    echo "✅ 存在"
else
    echo "❌ 不存在"
fi

# 2. 检查权限
echo -n "辅助功能权限: "
# 需要运行应用来检查

# 3. 检查 Chrome 数据文件
echo -n "Chrome 历史: "
if [ -f "$HOME/Library/Application Support/Google/Chrome/Default/History" ]; then
    echo "✅ 存在"
else
    echo "❌ 不存在"
fi

echo -n "Chrome 书签导出: "
if ls "$HOME/Documents/Spotlight/bookmarks_"*.html 1> /dev/null 2>&1; then
    echo "✅ 存在"
else
    echo "❌ 不存在"
fi

# 4. 检查日志
echo -n "日志目录: "
if [ -d "$HOME/Library/Logs/Spotlight" ]; then
    echo "✅ 存在"
    LOG_COUNT=$(ls "$HOME/Library/Logs/Spotlight"/*.log 2>/dev/null | wc -l)
    echo "  日志文件数: $LOG_COUNT"
else
    echo "❌ 不存在"
fi

# 5. 检查配置
echo -n "配置目录: "
if [ -d "$HOME/Library/Application Support/Spotlight" ]; then
    echo "✅ 存在"
else
    echo "❌ 不存在（首次运行会创建）"
fi

echo ""
echo "=== 诊断完成 ==="
```

保存为 `diagnose.sh` 并运行：
```bash
chmod +x diagnose.sh
./diagnose.sh
```

---

## 🆘 获取帮助

如果以上方法都无法解决问题：

1. **收集日志**
```bash
# 复制最新日志
cp ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log ~/Desktop/
```

2. **记录错误信息**
- 详细的操作步骤
- 错误截图
- 系统版本（关于本机 → macOS 版本）

3. **提交 Issue**
在项目仓库提交 Issue，附上以上信息。

---

**遇到问题不要慌，按步骤排查！** 🔧
