# 快速构建指南

由于环境差异,这里提供多种编译方式:

## 方式 1: 使用 Xcode (推荐)

1. 打开 Xcode
2. File → New → Project
3. 选择 macOS → App
4. 将 `Sources/` 目录下的所有 `.swift` 文件添加到项目
5. 在项目设置中:
   - Bundle Identifier: com.yourname.spotlight
   - Minimum Deployments: macOS 13.0
   - Frameworks: 确保链接了 Cocoa, SwiftUI, Carbon
6. Build (⌘B) 并 Run (⌘R)

## 方式 2: 命令行编译

```bash
# 确保已安装 Xcode (而非仅 Command Line Tools)
xcode-select --install

# 切换到 Xcode
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# 编译所有源文件
swiftc -o Spotlight \
    Sources/*.swift \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon

# 运行
./Spotlight
```

## 方式 3: 使用提供的脚本

```bash
chmod +x build.sh
./build.sh
```

## 首次运行权限设置

### 必需权限:
1. **辅助功能权限** (用于全局快捷键)
   - 系统设置 → 隐私与安全性 → 辅助功能
   - 添加 Spotlight 应用

### 可选权限:
2. **完全磁盘访问权限** (用于浏览器历史)
   - 系统设置 → 隐私与安全性 → 完全磁盘访问权限  
   - 添加 Spotlight 应用

## 常见问题

**Q: 编译失败,提示 "module.modulemap error" 或 "SDK is not supported by the compiler"**

A: 这是因为使用 Command Line Tools 编译时，SDK 和编译器版本不匹配。有以下几种解决方案：

### 解决方案 1: 安装并使用完整的 Xcode (强烈推荐)

```bash
# 1. 从 App Store 安装 Xcode
# 2. 打开 Xcode 一次，同意许可协议
# 3. 切换到 Xcode 的开发工具
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# 4. 验证切换成功
xcode-select -p
# 应该输出: /Applications/Xcode.app/Contents/Developer

# 5. 重新编译
swiftc -o Spotlight Sources/*.swift -framework Cocoa -framework SwiftUI -framework Carbon
```

### 解决方案 2: 更新 Command Line Tools

```bash
# 卸载旧版本
sudo rm -rf /Library/Developer/CommandLineTools

# 重新安装最新版本
xcode-select --install

# 或从 Apple Developer 网站下载最新的 Command Line Tools
# https://developer.apple.com/download/all/
```

### 解决方案 3: 使用 Xcode 项目 (最简单)

1. 打开 Xcode
2. File → New → Project
3. 选择 macOS → App
4. 项目名称: Spotlight
5. Interface: SwiftUI
6. Language: Swift
7. 将所有 `Sources/*.swift` 文件拖入项目
8. 在项目设置中:
   - Deployment Target: macOS 13.0
   - 在 "Signing & Capabilities" 中添加 App Sandbox (可选)
9. Build (⌘B) 并 Run (⌘R)

### 解决方案 4: 降级编译 (临时方案)

如果以上方案都不可行，可以暂时移除 SwiftUI 相关代码，仅编译核心功能：

```bash
# 仅编译基础功能（不含 UI）
swiftc -o Spotlight \
  Sources/main.swift \
  Sources/ConfigManager.swift \
  Sources/GlobalHotKeyMonitor.swift \
  -framework Cocoa \
  -framework Carbon
```

**Q: 快捷键不工作**
A: 检查是否授予了辅助功能权限。

**Q: 无法搜索浏览器历史**
A: 需要授予完全磁盘访问权限。

**Q: 运行时提示 "The application cannot be opened"**
A: 在系统设置 → 隐私与安全性中，点击 "仍要打开"。
