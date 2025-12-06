import XCTest
import Cocoa
@testable import Spotlight

/// End-to-End 测试 - 测试完整的用户流程
class SpotlightE2ETests: XCTestCase {
    
    var app: NSApplication!
    var delegate: AppDelegate!
    
    override func setUp() {
        super.setUp()
        app = NSApplication.shared
        delegate = AppDelegate()
    }
    
    override func tearDown() {
        delegate = nil
        super.tearDown()
    }
    
    // MARK: - 应用启动流程测试
    
    func testApplicationLaunchesSuccessfully() {
        // 测试应用能够成功启动
        XCTAssertNotNil(app)
        XCTAssertNotNil(delegate)
    }
    
    func testApplicationInitializesConfigManager() {
        // 模拟应用启动
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 验证 ConfigManager 已初始化
        XCTAssertNotNil(delegate.configManager)
    }
    
    func testApplicationCreatesStatusBarItem() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 验证状态栏图标已创建
        XCTAssertNotNil(delegate.statusItem)
    }
    
    func testApplicationCreatesSearchWindow() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 验证搜索窗口已创建
        XCTAssertNotNil(delegate.searchWindow)
    }
    
    func testApplicationInitializesHotKeyMonitor() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 验证热键监听器已初始化
        XCTAssertNotNil(delegate.globalHotKeyMonitor)
    }
    
    // MARK: - 搜索窗口交互测试
    
    func testSearchWindowToggle() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 初始应该隐藏
        XCTAssertFalse(delegate.searchWindow?.isVisible ?? true)
        
        // 切换显示
        delegate.toggleSearchWindow()
        
        // 应该显示
        XCTAssertTrue(delegate.searchWindow?.isVisible ?? false)
        
        // 再次切换
        delegate.toggleSearchWindow()
        
        // 应该隐藏
        XCTAssertFalse(delegate.searchWindow?.isVisible ?? true)
    }
    
    // MARK: - 完整用户流程测试
    
    func testCompleteSearchFlow() async {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 1. 显示搜索窗口
        delegate.toggleSearchWindow()
        XCTAssertTrue(delegate.searchWindow?.isVisible ?? false)
        
        // 2. 模拟搜索（通过 SearchViewController）
        guard let searchWindow = delegate.searchWindow else {
            XCTFail("搜索窗口未初始化")
            return
        }
        
        // 验证搜索窗口组件
        XCTAssertNotNil(searchWindow.searchViewController)
        
        // 3. 执行搜索
        let query = "Safari"
        searchWindow.searchViewController?.searchText = query
        searchWindow.searchViewController?.performSearch()
        
        // 等待搜索完成
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 4. 验证结果
        let results = searchWindow.searchViewController?.searchResults ?? []
        XCTAssertFalse(results.isEmpty, "应该返回搜索结果")
        
        // 5. 关闭窗口
        delegate.toggleSearchWindow()
        XCTAssertFalse(searchWindow.isVisible)
    }
    
    func testApplicationOpenFlow() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 测试打开应用的流程
        let testBundleID = "com.apple.Safari"
        
        // 这个测试仅验证方法不崩溃
        // 实际打开应用需要在真实环境中测试
        XCTAssertNoThrow(delegate.openApplication(testBundleID))
    }
    
    // MARK: - 配置保存和恢复测试
    
    func testConfigurationPersistence() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 修改配置
        let originalBrowserHistory = delegate.configManager.browserHistoryEnabled
        delegate.configManager.browserHistoryEnabled = !originalBrowserHistory
        delegate.configManager.saveConfig()
        
        // 创建新的 ConfigManager 实例
        let newConfigManager = ConfigManager()
        
        // 验证配置已保存
        XCTAssertEqual(newConfigManager.browserHistoryEnabled, !originalBrowserHistory)
        
        // 恢复原始配置
        delegate.configManager.browserHistoryEnabled = originalBrowserHistory
        delegate.configManager.saveConfig()
    }
    
    // MARK: - 错误处理测试
    
    func testOpenNonExistentApplication() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 尝试打开不存在的应用
        let nonExistentApp = "com.nonexistent.app"
        
        // 应该优雅地处理，不崩溃
        XCTAssertNoThrow(delegate.openApplication(nonExistentApp))
    }
    
    func testSearchWithEmptyQuery() async {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        guard let searchWindow = delegate.searchWindow else {
            XCTFail("搜索窗口未初始化")
            return
        }
        
        // 空查询
        searchWindow.searchViewController?.searchText = ""
        searchWindow.searchViewController?.performSearch()
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
        
        // 应该返回空结果
        let results = searchWindow.searchViewController?.searchResults ?? []
        XCTAssertTrue(results.isEmpty, "空查询应该返回空结果")
    }
    
    func testSearchWithVeryLongQuery() async {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        guard let searchWindow = delegate.searchWindow else {
            XCTFail("搜索窗口未初始化")
            return
        }
        
        // 超长查询
        let longQuery = String(repeating: "a", count: 1000)
        searchWindow.searchViewController?.searchText = longQuery
        
        // 应该不崩溃
        XCTAssertNoThrow(searchWindow.searchViewController?.performSearch())
    }
    
    // MARK: - 性能测试
    
    func testSearchPerformance() async {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        guard let searchWindow = delegate.searchWindow else {
            XCTFail("搜索窗口未初始化")
            return
        }
        
        // 测试搜索性能
        measure {
            searchWindow.searchViewController?.searchText = "app"
            searchWindow.searchViewController?.performSearch()
            
            // 等待搜索完成
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        }
    }
    
    func testWindowShowHidePerformance() {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        
        // 测试窗口显示/隐藏性能
        measure {
            for _ in 0..<10 {
                delegate.toggleSearchWindow()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
    }
}
