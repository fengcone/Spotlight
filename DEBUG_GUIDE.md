# 调试指南 - Spotlight

## 🐛 问题：无法在搜索框中输入

### 症状
- 呼出 Spotlight 窗口后
- 点击输入框或直接输入
- 听到错误提示音（beep）
- 无法输入任何文字

### 诊断步骤

#### 1. 查看日志输出

运行应用后，查看终端输出的详细日志：

```bash
./Spotlight 2>&1 | tee spotlight.log
```

关键日志标记：
- `🔍 ========== 显示搜索窗口 ==========` - 窗口显示
- `📝 创建 SearchTextField...` - 输入框创建
- `🎯 尝试设置 TextField 为 FirstResponder...` - 焦点设置
- `✅ TextField 已获得焦点` - 成功
- `❌ TextField 未能获得焦点!` - 失败（问题所在）

#### 2. 检查窗口状态

查看日志中的窗口状态：
```
❓ 窗口是否可见: true/false
❓ 窗口是否是 Key: true/false
❓ 窗口是否是 Main: true/false
```

**预期**:
- `isVisible: true`
- `isKeyWindow: true`
- `isMainWindow: true`

**问题**:
- 如果 `isKeyWindow: false`，说明窗口没有获得键盘焦点

#### 3. 检查 FirstResponder

查看日志：
```
❗ 当前 FirstResponder: Optional(...)
```

**预期**: FirstResponder 应该是 NSTextField
**问题**: 如果是其他对象，说明焦点被抢占

### 常见原因和解决方案

#### 原因 1: 窗口层级问题

**症状**: 窗口显示但无法获得焦点

**检查**:
```
❓ 窗口 Level: 3  (应该是 floating level)
```

**解决方案**:
已在代码中设置 `level = .floating`，确保窗口在最上层

#### 原因 2: 辅助功能权限未授予

**症状**: 
- 快捷键工作
- 但窗口无法获得焦点

**检查**:
```bash
# 查看权限检查日志
grep "权限" spotlight.log
```

**解决方案**:
1. 打开 **系统设置** → **隐私与安全性** → **辅助功能**
2. 确保 Spotlight 已勾选
3. 重启应用

#### 原因 3: NSTextField 配置问题

**症状**: TextField 存在但不可编辑

**检查日志**:
```
❓ TextField 可编辑: true/false
❓ TextField 启用: true/false
```

**解决方案**:
如果 `isEditable: false`，检查 SearchTextField 的创建代码

#### 原因 4: SwiftUI 和 AppKit 桥接问题

**症状**: NSHostingView 和 NSTextField 交互异常

**调试**:
```swift
// 在 updateNSView 中检查
print("Window: \(nsView.window)")
print("FirstResponder: \(nsView.window?.firstResponder)")
```

**解决方案**:
- 确保 NSHostingView 正确设置
- 延迟设置 FirstResponder（已实现）

#### 原因 5: 窗口激活顺序问题

**症状**: 窗口显示顺序错误

**检查日志顺序**:
```
1. 👁 makeKeyAndOrderFront...
2. ⚡ 激活应用...
3. 🎯 尝试设置 TextField 为 FirstResponder...
```

**解决方案**:
确保顺序正确，已在代码中实现

### 调试命令

#### 实时查看日志
```bash
# 运行并实时查看日志
./Spotlight 2>&1 | grep -E "(🔍|📝|🎯|✅|❌|⌨️)"
```

#### 过滤特定日志
```bash
# 只看窗口相关
./Spotlight 2>&1 | grep "窗口"

# 只看 TextField 相关
./Spotlight 2>&1 | grep "TextField"

# 只看错误
./Spotlight 2>&1 | grep "❌"
```

#### 保存完整日志
```bash
./Spotlight > spotlight_full.log 2>&1
```

### 预期的正常日志流程

```
🔔 收到快捷键动作: toggleSearch
🔍 切换搜索窗口
🔄 toggleSearchWindow() 被调用

🔍 ========== 显示搜索窗口 ==========
📍 窗口位置: (xxx, yyy)
📊 窗口大小: 600.0 x 400.0
👁 makeKeyAndOrderFront...
⚡ 激活应用...
❓ 窗口是否可见: true
❓ 窗口是否是 Key: true
❓ 窗口是否是 Main: true
🔄 重置搜索内容...
🔄 SearchViewController.resetSearch() 被调用
✅ 搜索状态已重置
✅ 搜索窗口显示完成

🔄 updateNSView - 当前文本: ''
🎯 尝试设置 TextField 为 FirstResponder...
❓ Window 存在: true
❓ Window 是 Key: true
❓ makeFirstResponder 结果: true
✅ TextField 已获得焦点

# 用户开始输入
⌨️ 文本变化: 's'
⌨️ 文本变化: 'sa'
⌨️ 文本变化: 'saf'
⌨️ 文本变化: 'safa'
⌨️ 文本变化: 'safar'
⌨️ 文本变化: 'safari'
```

### 异常日志示例

#### 问题：无法获得焦点
```
❌ TextField 未能获得焦点!
❗ 当前 FirstResponder: Optional(<NSView: 0x...>)
```

**原因**: FirstResponder 被其他视图占用
**解决**: 检查视图层级，确保 TextField 可以成为 FirstResponder

#### 问题：窗口不是 Key Window
```
❓ 窗口是否是 Key: false
❓ makeFirstResponder 结果: false
```

**原因**: 窗口激活失败
**解决**: 检查 `NSApp.activate(ignoringOtherApps: true)` 是否正确调用

### 进一步调试

如果以上方法都无法解决，尝试：

#### 1. 简化测试
```swift
// 创建最简单的输入框测试
let testField = NSTextField()
testField.isEditable = true
testField.isEnabled = true
window.contentView = testField
window.makeFirstResponder(testField)
```

#### 2. 使用 Xcode 调试器
```bash
# 在 Xcode 中运行
open -a Xcode Spotlight.xcodeproj

# 设置断点在：
- SearchTextField.updateNSView
- makeFirstResponder 调用处
```

#### 3. 检查系统日志
```bash
# 查看系统控制台
log stream --predicate 'process == "Spotlight"' --level debug
```

## 🔧 修复记录

### 已添加的调试功能

1. ✅ 窗口显示完整日志
2. ✅ TextField 创建和更新日志
3. ✅ FirstResponder 设置日志
4. ✅ 窗口状态检查日志
5. ✅ 用户输入事件日志
6. ✅ 快捷键触发日志

### 已修复的问题

1. ✅ 移除 Safari 历史支持（仅保留 Chrome）
2. ✅ 添加详细的调试日志输出
3. ✅ 改进窗口焦点设置逻辑

## 📞 报告问题

如果问题仍然存在，请提供：

1. **完整日志** - 运行 `./Spotlight > debug.log 2>&1`
2. **系统信息** - macOS 版本、Xcode 版本
3. **复现步骤** - 详细的操作步骤
4. **屏幕录制** - 如果可能，录制问题发生过程

---

**最后更新**: 2025-12-05
**状态**: 等待用户反馈日志输出
