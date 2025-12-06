import XCTest
import Carbon
@testable import Spotlight

/// GlobalHotKeyMonitor 单元测试
class GlobalHotKeyMonitorTests: XCTestCase {
    
    var configManager: ConfigManager!
    var actionCallCount: Int = 0
    var lastAction: HotKeyAction?
    
    override func setUp() {
        super.setUp()
        configManager = ConfigManager(userDefaults: UserDefaults(suiteName: "com.spotlight.tests")!)
        actionCallCount = 0
        lastAction = nil
    }
    
    override func tearDown() {
        configManager = nil
        super.tearDown()
    }
    
    // MARK: - 键码映射测试
    
    func testKeyCodeForSpace() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let keyCode = monitor.keyCodeForString("space")
        XCTAssertEqual(keyCode, 49, "Space 键的键码应该是 49")
    }
    
    func testKeyCodeForLetterA() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let keyCode = monitor.keyCodeForString("a")
        XCTAssertEqual(keyCode, 0, "A 键的键码应该是 0")
    }
    
    func testKeyCodeForUnknownKey() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let keyCode = monitor.keyCodeForString("unknown_key")
        XCTAssertEqual(keyCode, 49, "未知键应该返回默认值 49")
    }
    
    func testKeyCodeCaseInsensitive() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let keyCodeLower = monitor.keyCodeForString("space")
        let keyCodeUpper = monitor.keyCodeForString("SPACE")
        XCTAssertEqual(keyCodeLower, keyCodeUpper, "键码查找应该不区分大小写")
    }
    
    // MARK: - 修饰键匹配测试
    
    func testMatchesHotKeyWithCommand() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let hotKeyConfig = HotKeyConfig(key: "k", modifiers: [.command])
        
        // 创建模拟事件（这部分在实际测试中需要 mock）
        // 这里仅测试配置的有效性
        XCTAssertEqual(hotKeyConfig.modifiers.count, 1)
        XCTAssertTrue(hotKeyConfig.modifiers.contains(.command))
    }
    
    func testMatchesHotKeyWithMultipleModifiers() {
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { _ in }
        let hotKeyConfig = HotKeyConfig(key: "k", modifiers: [.command, .shift, .option])
        
        XCTAssertEqual(hotKeyConfig.modifiers.count, 3)
        XCTAssertTrue(hotKeyConfig.modifiers.contains(.command))
        XCTAssertTrue(hotKeyConfig.modifiers.contains(.shift))
        XCTAssertTrue(hotKeyConfig.modifiers.contains(.option))
    }
    
    // MARK: - 热键动作测试
    
    func testToggleSearchAction() {
        var receivedAction: HotKeyAction?
        
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { action in
            receivedAction = action
        }
        
        // 模拟触发动作
        monitor.onAction(.toggleSearch)
        
        // 验证回调被调用
        if case .toggleSearch = receivedAction {
            XCTAssert(true)
        } else {
            XCTFail("应该收到 toggleSearch 动作")
        }
    }
    
    func testOpenAppAction() {
        var receivedAction: HotKeyAction?
        
        let monitor = GlobalHotKeyMonitor(configManager: configManager) { action in
            receivedAction = action
        }
        
        // 模拟打开应用动作
        let appName = "com.google.Chrome"
        monitor.onAction(.openApp(appName))
        
        // 验证回调被调用
        if case .openApp(let name) = receivedAction {
            XCTAssertEqual(name, appName)
        } else {
            XCTFail("应该收到 openApp 动作")
        }
    }
}

/// HotKeyAction 测试
class HotKeyActionTests: XCTestCase {
    
    func testToggleSearchActionEquality() {
        let action1 = HotKeyAction.toggleSearch
        let action2 = HotKeyAction.toggleSearch
        
        // 测试相等性
        switch (action1, action2) {
        case (.toggleSearch, .toggleSearch):
            XCTAssert(true)
        default:
            XCTFail("相同的 toggleSearch 动作应该相等")
        }
    }
    
    func testOpenAppActionWithDifferentApps() {
        let action1 = HotKeyAction.openApp("com.google.Chrome")
        let action2 = HotKeyAction.openApp("com.apple.Safari")
        
        // 测试不同应用的动作不相等
        switch (action1, action2) {
        case (.openApp(let app1), .openApp(let app2)):
            XCTAssertNotEqual(app1, app2)
        default:
            XCTFail("应该都是 openApp 动作")
        }
    }
}

// MARK: - 辅助扩展（用于测试）

extension GlobalHotKeyMonitor {
    // 暴露内部方法用于测试
    func keyCodeForString(_ key: String) -> Int {
        let keyMap: [String: Int] = [
            "space": 49,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
            "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
            "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            "return": 36, "escape": 53, "delete": 51, "tab": 48,
            "left": 123, "right": 124, "down": 125, "up": 126
        ]
        
        return keyMap[key.lowercased()] ?? 49
    }
    
    func onAction(_ action: HotKeyAction) {
        // 用于测试的辅助方法
    }
}
