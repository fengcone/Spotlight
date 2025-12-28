# 开发指南

## 🛠 开发环境设置

### 前置要求

- macOS 13.0+
- Xcode 15.0+ 或 Command Line Tools
- Swift 5.9+

### 克隆和编译

```bash
# 克隆项目
git clone <repository-url>
cd Spotlight

# 编译
swift build

# 运行
.build/debug/Spotlight
```

## 📦 打包发布

### 生成 .app 应用

```bash
chmod +x package.sh
./package.sh
```

生成的应用位于 `.build/Spotlight.app`

### 签名配置

编辑 `Spotlight.entitlements`：

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.files.all</key>
<true/>
```

## 🧪 测试

### 运行测试

```bash
# 使用脚本
chmod +x run_tests.sh
./run_tests.sh

# 使用 Swift PM
swift test

# 运行特定测试
swift test --filter ConfigManagerTests
```

### 添加新测试

在 `Tests/UnitTests/` 或 `Tests/E2ETests/` 中创建测试文件：

```swift
import XCTest
@testable import Spotlight

final class MyNewTests: XCTestCase {
    func testExample() {
        // Arrange
        let sut = MyComponent()
        
        // Act
        let result = sut.doSomething()
        
        // Assert
        XCTAssertEqual(result, expected)
    }
}
```

## 🏗 架构说明

### MVVM 模式

```
View (SwiftUI)
    ↓
ViewModel (ObservableObject)
    ↓
Model / Service
```

### 核心模块

- **SearchWindow** - UI 层，负责显示和交互
- **SearchEngine** - 业务逻辑层，负责搜索
- **ConfigManager** - 配置管理
- **GlobalHotKeyMonitor** - 系统集成

### 数据流

```
用户输入 → SearchViewController → SearchEngine → 搜索结果 → UI 更新
```

## 🔌 添加新功能

### 添加新的搜索源

1. 在 `SearchEngine.swift` 中添加加载方法：

```swift
private func loadMyNewSource() {
    // 加载数据
}
```

2. 在 `search()` 方法中集成：

```swift
let myResults = searchMySource(query: keyword)
combined.append(contentsOf: myResults)
```

3. 添加优先级权重

### 添加新的快捷键命令

1. 在 `GlobalHotKeyMonitor.swift` 中定义动作：

```swift
enum HotKeyAction {
    case myNewAction
}
```

2. 在 `AppDelegate.swift` 中处理：

```swift
case .myNewAction:
    self?.handleMyAction()
```

## 📝 代码规范

### 命名约定

- 类/结构体: `PascalCase`
- 函数/变量: `camelCase`
- 常量: `camelCase`
- 私有成员: 添加 `private` 关键字

### 注释

```swift
// MARK: - 搜索功能

/// 执行搜索
/// - Parameter query: 搜索关键词
/// - Returns: 搜索结果数组
func search(query: String) async -> [SearchResult] {
    // 实现
}
```

### 日志

使用统一的日志函数：

```swift
log("信息")
log("警告", level: .warning)
log("错误", level: .error)
log("调试信息", level: .debug)
```

## 🐛 调试技巧

### 查看详细日志

```bash
# 运行时重定向日志
./Spotlight 2>&1 | tee debug.log

# 打包应用日志
tail -f ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

### 断点调试

使用 Xcode：

1. 创建 Xcode 项目
2. 添加源文件
3. 设置断点
4. 按 `⌘R` 运行

### 性能分析

```bash
# 使用 Instruments
instruments -t "Time Profiler" .build/debug/Spotlight
```

## 🔄 发布流程

1. 更新版本号
2. 运行所有测试
3. 更新 CHANGELOG
4. 打包应用
5. 创建 Release

## 🌐 IDE 项目集成

### 配置文件

编辑 `ide_config.json`：

```json
{
  "ides": [
    {
      "name": "My IDE",
      "prefix": "mi",
      "appPath": "/Applications/MyIDE.app",
      "urlScheme": "myide://open?file=",
      "projectPaths": [
        "~/Projects"
      ]
    }
  ]
}
```

### URL Scheme

IDE 需要支持通过 URL Scheme 打开项目：

```
myide://open?file=/path/to/project
```

## 📚 相关资源

- [Swift 文档](https://docs.swift.org)
- [SwiftUI 教程](https://developer.apple.com/tutorials/swiftui)
- [Carbon Framework](https://developer.apple.com/documentation/carbon)
- [SQLite3 API](https://sqlite.org/c3ref/intro.html)

---

**Happy Coding!** 💻
