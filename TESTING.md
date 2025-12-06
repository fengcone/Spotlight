# 测试文档 - Spotlight

## 📋 测试概览

本项目包含完整的测试体系，确保代码质量和功能稳定性。

### 测试类型

1. **单元测试** (`Tests/UnitTests/`)
   - 测试独立的组件和函数
   - 快速、隔离、可重复

2. **E2E 测试** (`Tests/E2ETests/`)
   - 测试完整的用户流程
   - 模拟真实使用场景

3. **性能测试**
   - 搜索性能
   - 窗口切换性能

## 🧪 测试覆盖

### ConfigManager 测试
- ✅ 默认配置验证
- ✅ 配置保存和加载
- ✅ 快捷键配置
- ✅ 浏览器历史开关
- ✅ JSON 序列化/反序列化

### SearchEngine 测试
- ✅ 模糊匹配算法
  - 精确匹配
  - 前缀匹配
  - 大小写不敏感
- ✅ 应用搜索
  - 系统应用查找
  - 首字母缩写搜索
- ✅ 浏览器历史搜索
- ✅ 结果排序和限制
- ✅ 边界情况处理

### GlobalHotKeyMonitor 测试
- ✅ 键码映射
- ✅ 修饰键匹配
- ✅ 热键动作触发
- ✅ 回调机制

### E2E 测试
- ✅ 应用启动流程
- ✅ 搜索窗口交互
- ✅ 完整搜索流程
- ✅ 配置持久化
- ✅ 错误处理
- ✅ 性能基准

## 🚀 运行测试

### 方法 1: 使用 Xcode (推荐)

1. 打开项目:
```bash
open Spotlight.xcodeproj
```

2. 在 Xcode 中:
   - 按 `⌘U` 运行所有测试
   - 或 Product → Test

3. 查看测试结果:
   - Test Navigator (`⌘6`)
   - 绿色✅表示通过
   - 红色❌表示失败

### 方法 2: 使用命令行

```bash
# 运行所有测试
xcodebuild test -scheme Spotlight -destination 'platform=macOS'

# 运行特定测试类
xcodebuild test -scheme Spotlight -only-testing:SpotlightTests/ConfigManagerTests

# 运行特定测试方法
xcodebuild test -scheme Spotlight -only-testing:SpotlightTests/ConfigManagerTests/testDefaultMainHotKey
```

### 方法 3: 使用测试脚本

```bash
chmod +x run_tests.sh
./run_tests.sh
```

## 📊 测试报告

测试结果会自动生成报告:

```
Tests/Reports/
├── test-results.xml     # JUnit 格式
├── coverage.html        # 代码覆盖率报告
└── performance.log      # 性能测试结果
```

### 查看覆盖率

```bash
# 生成覆盖率报告
xcodebuild test -scheme Spotlight -enableCodeCoverage YES

# 查看覆盖率
xcrun xccov view --report DerivedData/.../Coverage.profdata
```

## 🐛 发现的 Bug 和修复

### 已知问题清单

1. **ConfigManager 初始化问题**
   - ❌ 问题: 使用全局 UserDefaults 导致测试污染
   - ✅ 修复: 添加依赖注入，支持测试 UserDefaults

2. **搜索性能问题**
   - ❌ 问题: 大量应用时搜索较慢
   - ⚠️ 状态: 待优化 - 考虑添加索引

3. **热键冲突**
   - ❌ 问题: 与系统 Spotlight 冲突
   - ⚠️ 状态: 需要用户手动禁用系统 Spotlight

## 📝 测试最佳实践

### 编写新测试

1. **遵循 AAA 模式**:
```swift
func testExample() {
    // Arrange - 准备测试数据
    let config = ConfigManager()
    
    // Act - 执行操作
    config.saveConfig()
    
    // Assert - 验证结果
    XCTAssertNotNil(config.mainHotKey)
}
```

2. **使用描述性命名**:
```swift
// ✅ 好
func testSearchReturnsEmptyArrayWhenQueryIsEmpty()

// ❌ 差
func testSearch1()
```

3. **每个测试一个断言**:
```swift
// ✅ 好
func testMainHotKeyDefaultKey() {
    XCTAssertEqual(configManager.mainHotKey.key, "space")
}

func testMainHotKeyDefaultModifier() {
    XCTAssertTrue(configManager.mainHotKey.modifiers.contains(.command))
}

// ❌ 差
func testMainHotKey() {
    XCTAssertEqual(configManager.mainHotKey.key, "space")
    XCTAssertTrue(configManager.mainHotKey.modifiers.contains(.command))
    XCTAssertEqual(configManager.mainHotKey.modifiers.count, 1)
}
```

4. **清理测试数据**:
```swift
override func tearDown() {
    // 清理测试数据
    testDefaults.removePersistentDomain(forName: "com.spotlight.tests")
    super.tearDown()
}
```

### 测试隔离

- ✅ 使用独立的 UserDefaults suite
- ✅ 每个测试独立运行
- ✅ 不依赖测试执行顺序
- ✅ 清理副作用

### Mock 和 Stub

对于难以测试的组件（如全局快捷键），创建 Mock:

```swift
class MockHotKeyMonitor: GlobalHotKeyMonitor {
    var startCalled = false
    
    override func start() {
        startCalled = true
    }
}
```

## 🎯 测试目标

### 当前覆盖率
- ConfigManager: ~95%
- SearchEngine: ~85%
- GlobalHotKeyMonitor: ~70%
- UI 组件: ~40% (需要提升)

### 目标覆盖率
- 核心逻辑: ≥ 90%
- UI 组件: ≥ 60%
- 整体: ≥ 80%

## 🔍 调试测试

### 在测试中打印调试信息

```swift
func testExample() {
    print("🐛 Debug: searchResults = \(searchResults)")
    XCTAssertFalse(searchResults.isEmpty)
}
```

### 使用断点

1. 在测试代码中设置断点
2. 按 `⌘U` 运行测试
3. 调试器会在断点处暂停

### 查看测试日志

```bash
# 查看详细测试输出
xcodebuild test -scheme Spotlight -destination 'platform=macOS' | tee test.log
```

## 📚 参考资源

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing Best Practices](https://developer.apple.com/documentation/xctest/testing_best_practices)
- [Code Coverage in Xcode](https://developer.apple.com/documentation/xcode/code-coverage)

## 🤝 贡献测试

添加新功能时，请同时添加测试:

1. 创建对应的测试文件
2. 覆盖主要场景和边界情况
3. 确保所有测试通过
4. 更新本文档

---

**记住**: 好的测试是代码质量的保证！ ✅
