# 快速开始 - 解决编译问题

## 🚨 你当前遇到的问题

错误信息显示：SDK 版本和编译器版本不匹配
```
SDK built with Swift 6.1.0.110.5
Compiler version Swift 6.1.0.110.21
```

这是 Command Line Tools 的常见问题。

## ✅ 推荐解决方案（3 选 1）

### 方案 1: 使用 Xcode（最简单，强烈推荐）

#### 步骤 1: 确保已安装 Xcode
```bash
# 检查 Xcode 是否已安装
ls /Applications/Xcode.app
```

如果没有，从 App Store 安装 Xcode（免费）。

#### 步骤 2: 切换开发工具到 Xcode
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# 验证
xcode-select -p
# 应输出: /Applications/Xcode.app/Contents/Developer
```

#### 步骤 3: 编译
```bash
cd /Users/fengjianhui/WorkSpaceL/Spotlight

swiftc -o Spotlight \
  Sources/main.swift \
  Sources/AppDelegate.swift \
  Sources/ConfigManager.swift \
  Sources/GlobalHotKeyMonitor.swift \
  Sources/SearchWindow.swift \
  Sources/SearchEngine.swift \
  Sources/SettingsView.swift \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Carbon

# 运行
./Spotlight
```

### 方案 2: 使用 Xcode 图形界面（最稳定）

1. **打开 Xcode**

2. **创建新项目**
   - File → New → Project
   - 选择 macOS → App
   - Product Name: `Spotlight`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - 保存到任意位置

3. **添加源文件**
   - 删除 Xcode 自动生成的 `ContentView.swift` 和 `SpotlightApp.swift`
   - 将 `Sources/` 目录下的所有 `.swift` 文件拖入项目
   - 确保勾选 "Copy items if needed"

4. **配置项目**
   - 选中项目 → TARGETS → Spotlight
   - General → Deployment Info:
     - Deployment Target: `macOS 13.0`
   - Signing & Capabilities:
     - 选择你的开发团队（或使用个人签名）

5. **编译并运行**
   - 按 `⌘B` 编译
   - 按 `⌘R` 运行

6. **导出应用**
   - Product → Archive
   - Distribute App → Copy App
   - 将 `.app` 文件复制到 `/Applications`

### 方案 3: 更新 Command Line Tools（风险较高）

```bash
# 卸载现有的 Command Line Tools
sudo rm -rf /Library/Developer/CommandLineTools

# 重新安装
xcode-select --install

# 或从 Apple Developer 下载最新版本
# https://developer.apple.com/download/all/
# 搜索 "Command Line Tools for Xcode" 并下载与你的 macOS 版本匹配的
```

## 🎯 首次运行配置

### 1. 授予辅助功能权限（必需）

运行应用后，系统会提示需要权限：

1. 打开 **系统设置**
2. 前往 **隐私与安全性** → **辅助功能**
3. 点击 **+** 按钮添加 `Spotlight` 应用
4. 或在列表中找到 `Spotlight` 并勾选

### 2. 授予完全磁盘访问权限（可选，用于浏览器历史）

1. 打开 **系统设置**
2. 前往 **隐私与安全性** → **完全磁盘访问权限**
3. 点击 **+** 按钮添加 `Spotlight` 应用

### 3. 使用应用

- 按 `Command + Space` 呼出搜索窗口
- 输入关键词搜索应用或网址
- 使用 `↑` `↓` 键选择
- 按 `Enter` 打开
- 按 `Escape` 关闭

## 🔧 验证环境命令

运行以下命令检查你的开发环境：

```bash
# 检查当前使用的开发工具路径
xcode-select -p

# 检查 Swift 版本
swift --version

# 检查 SDK 路径
xcrun --show-sdk-path

# 检查可用的 SDK
xcrun --show-sdk-version
```

## 💡 推荐做法

**对于这个项目，我强烈推荐使用「方案 2: Xcode 图形界面」**，因为：

1. ✅ 不会有 SDK 版本问题
2. ✅ 自动处理代码签名
3. ✅ 可视化配置权限
4. ✅ 方便调试和开发
5. ✅ 可以直接导出 .app 文件

使用命令行编译仅适合已经有完整 Xcode 环境的开发者。

## ❓ 遇到其他问题？

查看 [`BUILD.md`](BUILD.md) 获取更多编译选项和常见问题解答。
