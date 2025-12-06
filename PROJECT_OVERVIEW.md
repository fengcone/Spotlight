# Spotlight 项目概览

## 📝 项目简介

这是一个为 macOS 打造的轻量级 Spotlight 替代品，专注于简洁、高效和个性化定制。

## 🎯 核心功能实现

### 1. 全局快捷键系统
**文件**: `GlobalHotKeyMonitor.swift`

- 使用 Carbon Framework 的 `RegisterEventHotKey` API
- 支持完全自定义的快捷键组合
- 默认: Command + Space
- 实现了热键事件的捕获和分发机制

**关键技术点**:
```swift
- EventHotKeyRef: 全局热键引用
- InstallEventHandler: 注册事件处理器
- NSEvent.addLocalMonitorForEvents: 本地事件监听
```

### 2. 搜索窗口 UI
**文件**: `SearchWindow.swift`

- 使用 SwiftUI 构建现代化界面
- NSHostingView 桥接 SwiftUI 和 AppKit
- 浮动窗口设计，始终置顶
- 支持键盘导航 (上下键选择，Enter 执行，Escape 关闭)

**特性**:
- 无边框窗口 (.borderless)
- 非激活面板 (.nonactivatingPanel)
- 半透明背景效果
- 自动居中显示

### 3. 智能搜索引擎
**文件**: `SearchEngine.swift`

**搜索源**:
1. **应用程序搜索**
   - 扫描 `/Applications`、`/System/Applications` 等目录
   - 提取应用元数据 (名称、Bundle ID、图标)
   - 缓存机制提升性能

2. **浏览器历史搜索**
   - Chrome: `~/Library/Application Support/Google/Chrome/Default/History`
   - Safari: `~/Library/Safari/History.db`
   - 直接读取 SQLite 数据库
   - 访问频率加权排序

**匹配算法**:
```
1. 精确匹配 (100 分)
2. 前缀匹配 (90 分)
3. 包含匹配 (80 分)
4. 模糊匹配 (基于字符序列, 最高 70 分)
```

### 4. 配置管理系统
**文件**: `ConfigManager.swift`

- 使用 UserDefaults 持久化配置
- ObservableObject + @Published 实现响应式更新
- JSON 序列化存储快捷键配置

**配置项**:
- 主快捷键
- 应用专属快捷键映射
- 浏览器历史开关

### 5. 设置界面
**文件**: `SettingsView.swift`

- TabView 多标签页设计:
  - 通用设置
  - 快捷键配置
  - 应用程序管理

- 热键录制器 (HotKeyRecorderView)
  - 实时捕获按键组合
  - 可视化显示修饰符 (⌘⌥⌃⇧)

### 6. 应用代理
**文件**: `AppDelegate.swift`

- 设置为辅助应用 (.accessory) - 不在 Dock 显示
- 管理状态栏图标
- 协调各模块交互

## 🗂 文件结构

```
Sources/
├── main.swift                    # 应用入口 (9 行)
├── AppDelegate.swift             # 应用代理和生命周期 (83 行)
├── ConfigManager.swift           # 配置管理和持久化 (102 行)
├── GlobalHotKeyMonitor.swift     # 全局快捷键监听 (120 行)
├── SearchWindow.swift            # 搜索窗口 UI (282 行)
├── SearchEngine.swift            # 搜索引擎和算法 (320+ 行)
└── SettingsView.swift            # 设置界面 (325 行)
```

**总代码量**: ~1,200 行

## 🔧 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI + AppKit (Cocoa) |
| 系统框架 | Carbon (快捷键)、NSWorkspace (应用管理) |
| 数据存储 | SQLite3 (浏览器历史)、UserDefaults (配置) |
| 架构模式 | MVVM (Model-View-ViewModel) |

## 🎨 设计模式

1. **观察者模式**: ConfigManager 使用 ObservableObject
2. **委托模式**: SearchViewController 的 onDismiss 回调
3. **单例模式**: NSWorkspace.shared
4. **策略模式**: 多种匹配算法 (精确、前缀、模糊)

## 🚀 工作流程

### 启动流程
```
1. main.swift 创建 NSApplication
2. AppDelegate.applicationDidFinishLaunching
   ├── 设置为辅助应用
   ├── 初始化 ConfigManager
   ├── 创建状态栏图标
   ├── 初始化 SearchWindow
   └── 启动 GlobalHotKeyMonitor
```

### 搜索流程
```
1. 用户按下快捷键 (Command + Space)
2. GlobalHotKeyMonitor 捕获事件
3. AppDelegate.toggleSearchWindow()
4. SearchWindow.show()
   ├── 窗口居中并显示
   ├── TextField 自动获取焦点
   └── 等待用户输入
5. 用户输入关键词
6. SearchViewController.performSearch()
7. SearchEngine.search(query)
   ├── 搜索应用程序
   ├── 搜索浏览器历史
   ├── 计算匹配分数
   └── 排序返回结果
8. 用户选择结果并按 Enter
9. SearchViewController.executeSelected()
   └── 打开应用/网址/文件
10. 窗口自动隐藏
```

## 📊 性能优化

1. **应用列表缓存**: 启动时一次性扫描，避免重复
2. **浏览器历史限制**: 只读取前 500 条最常访问
3. **结果数量限制**: 最多显示 10 个搜索结果
4. **异步搜索**: 使用 async/await 避免阻塞 UI

## 🔐 权限需求

| 权限 | 用途 | 必需性 |
|------|------|--------|
| 辅助功能 | 全局快捷键监听 | ✅ 必需 |
| 完全磁盘访问 | 读取浏览器历史数据库 | ⚠️ 可选 |

## 🎯 已实现功能清单

- ✅ 自定义全局快捷键
- ✅ 应用程序搜索和启动
- ✅ 浏览器历史集成 (Chrome + Safari)
- ✅ 智能模糊匹配
- ✅ 键盘导航支持
- ✅ 设置界面
- ✅ 快捷键自定义
- ✅ 配置持久化
- ✅ 状态栏菜单

## 🔜 后续扩展方向

1. **更多搜索源**:
   - 文件系统搜索 (Spotlight 索引)
   - 书签同步
   - 剪贴板历史
   - 计算器功能
   - Web 搜索快捷方式

2. **性能优化**:
   - 增量索引更新
   - 更智能的缓存策略
   - 多线程搜索

3. **UI 增强**:
   - 自定义主题
   - 结果预览
   - 动画效果

4. **扩展性**:
   - 插件系统
   - 自定义动作 (Actions)
   - 工作流集成

## 💡 使用建议

1. **日常使用**: 用于快速启动应用和打开网页
2. **开发环境**: 快速切换开发工具 (IDE、终端、浏览器)
3. **定制化**: 根据个人习惯配置专属快捷键

## 📚 相关资源

- [Carbon Event Manager](https://developer.apple.com/documentation/carbon/event_manager)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [NSWorkspace API](https://developer.apple.com/documentation/appkit/nsworkspace)

---

**版本**: 1.0.0  
**最后更新**: 2025-12-05
