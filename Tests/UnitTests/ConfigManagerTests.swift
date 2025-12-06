import XCTest
import Foundation
@testable import Spotlight

/// ConfigManager 单元测试
class ConfigManagerTests: XCTestCase {
    
    var configManager: ConfigManager!
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // 使用测试专用的 UserDefaults
        testDefaults = UserDefaults(suiteName: "com.spotlight.tests")
        testDefaults.removePersistentDomain(forName: "com.spotlight.tests")
        configManager = ConfigManager(userDefaults: testDefaults)
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.spotlight.tests")
        testDefaults = nil
        configManager = nil
        super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    func testDefaultMainHotKey() {
        // 验证默认主快捷键是 Command + Space
        XCTAssertEqual(configManager.mainHotKey.key, "space")
        XCTAssertEqual(configManager.mainHotKey.modifiers.count, 1)
        XCTAssertTrue(configManager.mainHotKey.modifiers.contains(.command))
    }
    
    func testDefaultBrowserHistoryEnabled() {
        // 验证默认启用浏览器历史
        XCTAssertTrue(configManager.browserHistoryEnabled)
    }
    
    func testDefaultAppHotKeysEmpty() {
        // 验证默认应用快捷键为空
        XCTAssertTrue(configManager.appHotKeys.isEmpty)
    }
    
    // MARK: - 保存和加载测试
    
    func testSaveAndLoadMainHotKey() {
        // 修改主快捷键
        let newHotKey = HotKeyConfig(key: "k", modifiers: [.command, .shift])
        configManager.mainHotKey = newHotKey
        configManager.saveConfig()
        
        // 创建新实例验证加载
        let newConfigManager = ConfigManager(userDefaults: testDefaults)
        XCTAssertEqual(newConfigManager.mainHotKey.key, "k")
        XCTAssertEqual(newConfigManager.mainHotKey.modifiers.count, 2)
        XCTAssertTrue(newConfigManager.mainHotKey.modifiers.contains(.command))
        XCTAssertTrue(newConfigManager.mainHotKey.modifiers.contains(.shift))
    }
    
    func testSaveAndLoadBrowserHistory() {
        // 禁用浏览器历史
        configManager.browserHistoryEnabled = false
        configManager.saveConfig()
        
        // 验证加载
        let newConfigManager = ConfigManager(userDefaults: testDefaults)
        XCTAssertFalse(newConfigManager.browserHistoryEnabled)
    }
    
    func testAddAppHotKey() {
        // 添加应用快捷键
        let hotKey = HotKeyConfig(key: "c", modifiers: [.command, .shift])
        configManager.addAppHotKey(appName: "com.google.Chrome", hotKey: hotKey)
        
        // 验证
        XCTAssertEqual(configManager.appHotKeys.count, 1)
        XCTAssertNotNil(configManager.appHotKeys["com.google.Chrome"])
        XCTAssertEqual(configManager.appHotKeys["com.google.Chrome"]?.key, "c")
    }
    
    // MARK: - HotKeyConfig 测试
    
    func testCarbonModifiersCommand() {
        let hotKey = HotKeyConfig(key: "space", modifiers: [.command])
        XCTAssertTrue(hotKey.carbonModifiers != 0)
    }
    
    func testCarbonModifiersMultiple() {
        let hotKey = HotKeyConfig(key: "k", modifiers: [.command, .shift, .option])
        XCTAssertTrue(hotKey.carbonModifiers != 0)
    }
    
    func testHotKeyConfigCodable() throws {
        // 测试编码和解码
        let hotKey = HotKeyConfig(key: "space", modifiers: [.command, .option])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(hotKey)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HotKeyConfig.self, from: data)
        
        XCTAssertEqual(decoded.key, hotKey.key)
        XCTAssertEqual(decoded.modifiers, hotKey.modifiers)
    }
    
    // MARK: - 默认应用映射测试
    
    func testGetDefaultAppMappings() {
        let mappings = configManager.getDefaultAppMappings()
        
        // 验证包含常用应用
        XCTAssertTrue(mappings.keys.contains("com.google.Chrome"))
        XCTAssertTrue(mappings.keys.contains("com.googlecode.iterm2"))
        XCTAssertTrue(mappings.keys.contains("com.apple.Safari"))
    }
}
