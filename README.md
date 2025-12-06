# Spotlight - 轻量级 macOS 搜索工具

一个简洁、高效的 macOS Spotlight 替代品，专为个人定制化需求打造。

## ✨ 功能特性

### 1. 🎯 全局快捷键
- **自定义主快捷键**：默认 `Command + Space`，可在设置中自定义
- **全局任意位置呼出**：无需切换应用，随时随地快速启动

### 2. ⚡️ 应用快速启动
- 支持搜索并打开已安装的应用程序
- 可设置专属快捷键直接打开常用应用（Chrome、iTerm2、VSCode 等）
- 智能模糊匹配，输入首字母即可快速定位

### 3. 🌐 浏览器集成
- **Chrome 书签搜索**：快速访问收藏的网页
- **Chrome 历史记录搜索**：自动读取浏览历史
- **智能排序**：应用 > 书签 > 历史，根据访问频率和匹配度排序
- **自动补全**：输入关键词（如 "qoder"）自动联想并补全网址

### 4. 🎨 现代化界面
- 简洁的 SwiftUI 设计
- 浮动窗口，始终置顶
- 不在 Dock 显示，不干扰工作流
- 支持键盘上下键选择结果
- 按 Enter 执行，Escape 关闭

## 📋 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Swift 5.9+

## 🚀 快速开始

### 方法 1: 打包安装（推荐）

```bash
# 赋予执行权限
chmod +x package.sh

# 打包成 .app 应用
./package.sh

# 安装到应用目录
cp -r .build/Spotlight.app /Applications/
# 或者
cp -r .build/Spotlight.app ~/Applications/
```

打包后可以：
- 在 Finder 中双击 `Spotlight.app` 启动
- 在 Launchpad 中找到并运行
- 设置为开机自启动

### 方法 2: 直接编译运行

```bash
# 赋予执行权限
chmod +x build.sh

# 执行构建
./build.sh

# 运行
.build/Spotlight
```

### 首次运行

1. **辅助功能权限**：首次运行时，macOS 会提示授予辅助功能权限
   - 打开 `系统设置` → `隐私与安全性` → `辅助功能`
   - 添加 Spotlight 应用

2. **完全磁盘访问权限**（可选）：用于读取浏览器历史
   - 打开 `系统设置` → `隐私与安全性` → `完全磁盘访问权限`
   - 添加 Spotlight 应用

## 🎮 使用指南

### 基本操作

1. **呼出搜索窗口**：按 `Command + Space`（可自定义）
2. **输入关键词**：开始输入应用名称或网址关键词
3. **选择结果**：
   - 使用 `↑` `↓` 键选择
   - 或直接点击鼠标
4. **执行**：按 `Enter` 或点击
5. **关闭**：按 `Escape` 或点击窗口外部

### 设置快捷键

1. 点击菜单栏图标 🔍
2. 选择 "设置"
3. 在 "快捷键" 标签页中配置：
   - 主快捷键（呼出搜索窗口）
   - 应用专属快捷键

### 浏览器历史搜索示例

输入 "qoder"：
```
🔍 Qoder - AI Code Editor
   https://qoder.example.com
```

输入 "github"：
```
🔍 GitHub - Your Projects
   https://github.com/your-username
```

## 📁 项目结构

```
Spotlight/
├── Sources/
│   ├── main.swift            # 应用入口
│   ├── AppDelegate.swift     # 应用代理
│   ├── ConfigManager.swift   # 配置管理
│   ├── GlobalHotKeyMonitor.swift  # 全局快捷键监听
│   ├── SearchWindow.swift    # 搜索窗口 UI
│   ├── SearchEngine.swift    # 搜索引擎
│   └── SettingsView.swift    # 设置界面
├── build.sh                  # 构建脚本
├── package.sh                # 打包脚本（生成 .app）
└── README.md                 # 项目文档
```

## 🔧 技术栈

- **语言**：Swift
- **UI 框架**：SwiftUI
- **系统框架**：
  - Cocoa (窗口管理)
  - Carbon (全局快捷键)
  - SQLite (浏览器历史读取)

## 🎯 核心特性实现

### 全局快捷键
使用 Carbon Framework 的 `RegisterEventHotKey` API 实现系统级快捷键监听

### 浏览器集成
直接读取 Chrome 的数据文件：
- 书签: `~/Library/Application Support/Google/Chrome/Default/Bookmarks` (JSON)
- 历史: `~/Library/Application Support/Google/Chrome/Default/History` (SQLite)

### 模糊匹配算法
支持多种匹配策略：
- 精确匹配
- 前缀匹配
- 包含匹配
- 首字母缩写匹配

## 📝 待办事项

- [ ] 支持更多浏览器（Firefox、Edge）
- [ ] 文件系统搜索
- [ ] 计算器功能
- [ ] 书签同步
- [ ] 插件系统

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**享受你的个性化 Spotlight！** 🚀
