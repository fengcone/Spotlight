import XCTest
import Foundation
@testable import Spotlight

/// SearchEngine 单元测试
class SearchEngineTests: XCTestCase {
    
    var configManager: ConfigManager!
    var searchEngine: SearchEngine!
    
    override func setUp() {
        super.setUp()
        configManager = ConfigManager(userDefaults: UserDefaults(suiteName: "com.spotlight.tests")!)
        searchEngine = SearchEngine(configManager: configManager)
    }
    
    override func tearDown() {
        searchEngine = nil
        configManager = nil
        super.tearDown()
    }
    
    // MARK: - 模糊匹配测试
    
    func testFuzzyMatchExactMatch() async {
        // 测试精确匹配应该得到最高分
        let results = await searchEngine.search(query: "Safari")
        let safariResult = results.first { $0.title.contains("Safari") }
        
        if let result = safariResult {
            // 精确匹配应该有较高分数
            XCTAssertGreaterThan(result.score, 80.0)
        }
    }
    
    func testFuzzyMatchPrefixMatch() async {
        // 测试前缀匹配
        let results = await searchEngine.search(query: "Saf")
        let safariResults = results.filter { $0.title.contains("Safari") }
        
        XCTAssertFalse(safariResults.isEmpty, "应该能找到 Safari")
    }
    
    func testFuzzyMatchCaseInsensitive() async {
        // 测试大小写不敏感
        let results1 = await searchEngine.search(query: "safari")
        let results2 = await searchEngine.search(query: "SAFARI")
        let results3 = await searchEngine.search(query: "Safari")
        
        // 所有搜索应该返回相似的结果
        XCTAssertFalse(results1.isEmpty)
        XCTAssertFalse(results2.isEmpty)
        XCTAssertFalse(results3.isEmpty)
    }
    
    func testEmptyQueryReturnsEmpty() async {
        // 空查询应该返回空结果
        let results = await searchEngine.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSearchResultsLimitedTo10() async {
        // 结果应该限制在 10 个以内
        let results = await searchEngine.search(query: "a")
        XCTAssertLessThanOrEqual(results.count, 10)
    }
    
    func testSearchResultsSortedByScore() async {
        // 结果应该按分数排序
        let results = await searchEngine.search(query: "app")
        
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].score, results[i + 1].score,
                                       "结果应该按分数降序排列")
        }
    }
    
    // MARK: - 应用搜索测试
    
    func testApplicationSearchFindsSystemApps() async {
        // 应该能找到系统应用
        let results = await searchEngine.search(query: "Safari")
        let hasSafari = results.contains { $0.type == .application && $0.title.contains("Safari") }
        
        XCTAssertTrue(hasSafari, "应该能找到 Safari 应用")
    }
    
    func testApplicationSearchWithAbbreviation() async {
        // 测试首字母缩写搜索
        let results = await searchEngine.search(query: "sf")
        
        // 应该能找到某些匹配的应用
        XCTAssertFalse(results.isEmpty)
    }
    
    // MARK: - 浏览器历史测试
    
    func testBrowserHistoryDisabled() async {
        // 禁用浏览器历史
        configManager.browserHistoryEnabled = false
        let newEngine = SearchEngine(configManager: configManager)
        
        let results = await newEngine.search(query: "google")
        
        // 结果中不应该包含 URL 类型
        let hasURLs = results.contains { $0.type == .url }
        XCTAssertFalse(hasURLs, "禁用浏览器历史后不应返回 URL 结果")
    }
    
    // MARK: - SearchResult 测试
    
    func testSearchResultHasRequiredFields() async {
        let results = await searchEngine.search(query: "Safari")
        
        for result in results {
            XCTAssertFalse(result.title.isEmpty, "标题不应为空")
            XCTAssertFalse(result.path.isEmpty, "路径不应为空")
            XCTAssertGreaterThan(result.score, 0, "分数应该大于0")
        }
    }
    
    func testSearchResultTypesAreValid() async {
        let results = await searchEngine.search(query: "app")
        
        for result in results {
            // 类型应该是有效的枚举值
            switch result.type {
            case .application, .url, .file:
                break // 有效类型
            }
        }
    }
}

/// ApplicationInfo 测试
class ApplicationInfoTests: XCTestCase {
    
    func testApplicationInfoFromValidPath() {
        // 测试从有效路径创建 ApplicationInfo
        let safariPath = "/Applications/Safari.app"
        
        if let appInfo = ApplicationInfo.from(path: safariPath) {
            XCTAssertEqual(appInfo.name, "Safari")
            XCTAssertEqual(appInfo.path, safariPath)
            XCTAssertNotNil(appInfo.bundleIdentifier)
            XCTAssertNotNil(appInfo.icon)
        } else {
            XCTFail("应该能从 Safari.app 创建 ApplicationInfo")
        }
    }
    
    func testApplicationInfoFromInvalidPath() {
        // 测试从无效路径创建应该返回 nil
        let invalidPath = "/NonExistent/App.app"
        let appInfo = ApplicationInfo.from(path: invalidPath)
        
        XCTAssertNil(appInfo, "无效路径应该返回 nil")
    }
}
