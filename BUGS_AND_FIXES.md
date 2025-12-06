# Bug 追踪和修复清单

## 🐛 已知 Bug 清单

### 高优先级 (P0 - 必须修复)

#### 1. ❌ 应用启动后快捷键不响应
**描述**: 首次运行应用后，按 Command+Space 没有反应
**原因**: 需要辅助功能权限，但应用没有提示用户
**状态**: ⚠️ 待修复
**修复方案**:
```swift
// 添加权限检查和引导
func checkAccessibilityPermission() {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        showPermissionAlert()
    }
}
```

#### 2. ❌ 搜索窗口无法通过 Escape 关闭
**描述**: 按 Escape 键窗口不关闭
**原因**: NSTextField 的 delegate 方法可能未正确处理 cancel operation
**状态**: ⚠️ 待修复
**修复方案**: 已在 SearchTextField.Coordinator 中添加处理

#### 3. ❌ 浏览器历史搜索崩溃
**描述**: 启用浏览器历史搜索时应用崩溃
**原因**: 
- SQLite 数据库被浏览器锁定
- 没有完全磁盘访问权限
**状态**: ⚠️ 待修复
**修复方案**:
```swift
// 添加错误处理和权限检查
do {
    try FileManager.default.copyItem(atPath: historyPath, toPath: tempPath)
} catch {
    print("无法访问浏览器历史: \(error)")
    return []
}
```

### 中优先级 (P1 - 应该修复)

#### 4. ⚠️ 搜索性能慢
**描述**: 输入搜索关键词后，结果返回较慢（>1秒）
**原因**: 
- 每次搜索都扫描所有应用
- 没有缓存机制
**状态**: ⚠️ 待优化
**修复方案**:
- 添加应用索引缓存
- 使用增量搜索
- 限制搜索范围

#### 5. ⚠️ 窗口位置不固定
**描述**: 每次呼出窗口位置不一致
**原因**: 窗口居中逻辑可能有问题
**状态**: ⚠️ 待修复
**修复方案**:
```swift
func centerWindow() {
    if let screen = NSScreen.main {
        let screenRect = screen.visibleFrame
        let windowRect = frame
        let x = screenRect.midX - windowRect.width / 2
        let y = screenRect.midY + screenRect.height / 4
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
```

#### 6. ⚠️ 长查询字符串导致 UI 卡顿
**描述**: 输入超长字符串（>100字符）时 UI 卡顿
**原因**: 搜索在主线程执行
**状态**: ⚠️ 待修复
**修复方案**: 已使用 async/await，确保在后台线程执行

### 低优先级 (P2 - 可以稍后修复)

#### 7. 📝 设置窗口无法打开
**描述**: 点击状态栏的"设置"菜单项没反应
**原因**: SettingsWindowController 初始化可能有问题
**状态**: ⚠️ 待修复

#### 8. 📝 应用图标显示不正确
**描述**: 某些应用的图标显示为默认图标
**原因**: NSWorkspace.icon(forFile:) 对某些路径失效
**状态**: ⚠️ 待修复

#### 9. 📝 热键录制器界面不美观
**描述**: 热键录制窗口样式简陋
**原因**: UI 设计不够精致
**状态**: ⚠️ 待优化

## ✅ 已修复 Bug

### 1. ✅ ConfigManager 测试污染
**描述**: 测试之间相互影响
**修复**: 添加依赖注入，使用独立的 UserDefaults
**提交**: [修复链接]

### 2. ✅ SQLite3 导入缺失
**描述**: SearchEngine 编译失败
**修复**: 添加 `import SQLite3`
**提交**: [修复链接]

### 3. ✅ Carbon 框架常量未定义
**描述**: ConfigManager 编译失败，找不到 cmdKey 等常量
**修复**: 添加 `import Carbon`
**提交**: [修复链接]

## 🔍 Bug 报告模板

发现新 Bug 时，请使用以下模板报告：

```markdown
### Bug 标题

**优先级**: P0 / P1 / P2
**描述**: 详细描述 Bug 的表现
**复现步骤**:
1. 步骤 1
2. 步骤 2
3. 步骤 3

**预期行为**: 应该发生什么
**实际行为**: 实际发生了什么
**环境**:
- macOS 版本: 
- Xcode 版本:
- Swift 版本:

**错误日志**:
```
粘贴错误日志
```

**截图**: (如果适用)

**可能的原因**: 初步分析
**修复方案**: 建议的修复方法
```

## 🛠 修复工作流程

1. **确认 Bug**
   - 验证 Bug 可复现
   - 添加到此文档

2. **编写测试**
   - 创建能复现 Bug 的测试用例
   - 确保测试失败

3. **修复 Bug**
   - 实现修复
   - 确保测试通过

4. **回归测试**
   - 运行所有测试
   - 确保没有引入新 Bug

5. **更新文档**
   - 标记 Bug 为已修复
   - 更新相关文档

## 📊 Bug 统计

- 总计: 9 个
- 高优先级 (P0): 3 个 ⚠️
- 中优先级 (P1): 3 个 ⚠️
- 低优先级 (P2): 3 个 📝
- 已修复: 3 个 ✅

**修复率**: 33% (3/9)

## 🎯 下一步行动

### 本周计划
1. 修复所有 P0 Bug
2. 添加权限检查和引导
3. 优化搜索性能

### 本月计划
1. 修复所有 P1 Bug
2. 提升测试覆盖率到 80%+
3. 完善文档

---

**最后更新**: 2025-12-05
