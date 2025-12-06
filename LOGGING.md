# 日志系统说明

## 📝 功能概述

Spotlight 应用内置了完整的日志系统，用于记录应用运行状态和调试信息。

## 🎯 工作原理

### 自动检测模式

日志系统会自动检测应用运行模式：

1. **开发模式**（直接运行二进制文件）
   - 日志只输出到控制台
   - 不写入文件
   - 便于实时调试

2. **打包模式**（运行 .app 应用）
   - 日志同时输出到控制台和文件
   - 文件路径：`~/Library/Logs/Spotlight/`
   - 按日期自动创建日志文件

### 日志格式

每条日志包含：
- **时间戳**：精确到秒（格式：`yyyy-MM-dd HH:mm:ss`）
- **日志级别**：DEBUG / INFO / WARN / ERROR
- **日志内容**：实际的日志消息

示例：
```
[2025-12-06 00:30:15] [INFO] 🚀 Spotlight 启动...
[2025-12-06 00:30:15] [INFO] 🛠 设置窗口属性...
[2025-12-06 00:30:15] [INFO] ✅ 窗口属性设置完成
[2025-12-06 00:30:16] [INFO] 📚 开始加载浏览器历史...
[2025-12-06 00:30:16] [INFO] ✅ 浏览器历史加载完成，共 500 条记录
```

## 📂 日志文件位置

### 日志目录
```
~/Library/Logs/Spotlight/
```

### 文件命名规则
```
spotlight-YYYY-MM-DD.log
```

例如：
- `spotlight-2025-12-06.log` - 2025年12月6日的日志
- `spotlight-2025-12-07.log` - 2025年12月7日的日志

每天自动创建新的日志文件，便于管理和查找。

## 🔍 查看日志

### 方法1: Finder 打开
```bash
open ~/Library/Logs/Spotlight/
```

### 方法2: 终端查看
```bash
# 查看今天的日志
cat ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log

# 实时跟踪日志（tail -f）
tail -f ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log

# 查看最近50行
tail -50 ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log

# 搜索特定关键词
grep "ERROR" ~/Library/Logs/Spotlight/*.log
grep "启动" ~/Library/Logs/Spotlight/*.log
```

### 方法3: Console.app
1. 打开"控制台"应用（Console.app）
2. 在左侧选择"用户报告" → "Spotlight"
3. 可以实时查看和过滤日志

## 📊 日志级别说明

| 级别 | 用途 | 示例 |
|------|------|------|
| DEBUG | 详细调试信息 | 内部状态变化、变量值 |
| INFO | 一般信息 | 启动、关闭、功能执行 |
| WARN | 警告信息 | 文件不存在、权限不足 |
| ERROR | 错误信息 | 异常、崩溃、严重问题 |

## 🔧 开发者使用

### 在代码中记录日志

```swift
// 方法1: 使用全局函数
log("这是一条信息日志")
log("这是一条警告", level: .warning)
log("这是一条错误", level: .error)

// 方法2: 直接使用 Logger
Logger.shared.log("详细的调试信息", level: .debug)
```

### 关闭日志（应用退出时）

```swift
// 应用退出时自动调用
Logger.shared.close()
```

## 🧹 日志维护

### 清理旧日志

日志文件按日期命名，可以手动删除旧的日志文件：

```bash
# 删除7天前的日志
find ~/Library/Logs/Spotlight/ -name "*.log" -mtime +7 -delete

# 查看日志目录占用空间
du -sh ~/Library/Logs/Spotlight/

# 删除所有日志（谨慎操作）
rm -rf ~/Library/Logs/Spotlight/*.log
```

### 自动清理脚本（可选）

创建一个定时任务自动清理30天前的日志：

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每天凌晨2点执行）
0 2 * * * find ~/Library/Logs/Spotlight/ -name "*.log" -mtime +30 -delete
```

## 🐛 调试技巧

### 1. 查找错误
```bash
grep -n "ERROR\|⚠️\|❌" ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

### 2. 查看启动过程
```bash
grep "启动\|完成\|设置" ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

### 3. 监控特定功能
```bash
# 监控搜索功能
tail -f ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log | grep "搜索"

# 监控快捷键
tail -f ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log | grep "快捷键"
```

## 📋 示例日志内容

### 正常启动
```
=== Spotlight Log Started at 2025-12-06 00:30:12 ===

[2025-12-06 00:30:12] [INFO] 🚀 Spotlight 启动...
[2025-12-06 00:30:12] [INFO] 🛠 设置窗口属性...
[2025-12-06 00:30:12] [INFO] ❓ 窗口 Level: 3
[2025-12-06 00:30:12] [INFO] ❓ 窗口不透明: false
[2025-12-06 00:30:12] [INFO] ❓ 窗口最小大小: (600.0, 400.0)
[2025-12-06 00:30:12] [INFO] ✅ 窗口属性设置完成
[2025-12-06 00:30:12] [INFO] 📝 设置窗口内容...
[2025-12-06 00:30:13] [INFO] 📚 开始加载浏览器历史...
[2025-12-06 00:30:13] [INFO] ✅ Chrome 书签加载完成，共 127 条记录
[2025-12-06 00:30:14] [INFO] ✅ 浏览器历史加载完成，共 500 条记录
[2025-12-06 00:30:14] [INFO] ✅ 窗口内容设置完成
[2025-12-06 00:30:14] [INFO] ⌨️ 设置全局快捷键监听...
[2025-12-06 00:30:14] [INFO] ✅ 快捷键监听启动完成
[2025-12-06 00:30:14] [INFO] ✅ Spotlight 启动完成
```

### 搜索操作
```
[2025-12-06 00:31:25] [INFO] 🔔 收到快捷键动作: toggleSearch
[2025-12-06 00:31:25] [INFO] 🔍 切换搜索窗口
[2025-12-06 00:31:25] [INFO] 🔍 ========== 显示搜索窗口 ==========
[2025-12-06 00:31:25] [INFO] 📍 窗口位置: (940.5, 1061.25)
[2025-12-06 00:31:25] [INFO] 📊 窗口大小: 600.0 x 400.0
[2025-12-06 00:31:25] [INFO] ✅ 搜索窗口显示完成
[2025-12-06 00:31:28] [INFO] ⌨️ 文本变化: 'chrome'
[2025-12-06 00:31:28] [INFO] 🔍 执行搜索: 'chrome'
[2025-12-06 00:31:28] [INFO] ✅ 搜索完成，找到 5 个结果
```

### 异常情况
```
[2025-12-06 00:32:10] [WARN] ⚠️ Chrome 历史文件不存在
[2025-12-06 00:32:10] [ERROR] ⚠️ 无法访问 Chrome 历史: Permission denied
[2025-12-06 00:32:10] [INFO] 💡 提示: 需要在系统设置中授予'完全磁盘访问权限'
```

### 正常退出
```
[2025-12-06 00:35:42] [INFO] 🛑 Spotlight 正在退出...

=== Spotlight Log Ended at 2025-12-06 00:35:42 ===
```

## ⚠️ 注意事项

1. **隐私保护**：日志文件可能包含搜索历史和浏览记录，请妥善保管
2. **磁盘空间**：长期运行会产生大量日志，建议定期清理
3. **性能影响**：日志写入对性能影响极小，无需担心
4. **开发调试**：开发时直接运行二进制文件，日志只在控制台显示，无文件写入

## 🔗 相关文件

- **日志实现**：`Sources/Logger.swift`
- **应用生命周期**：`Sources/AppDelegate.swift`
- **打包脚本**：`package.sh`

---

**享受完善的日志系统带来的便利！** 📝
