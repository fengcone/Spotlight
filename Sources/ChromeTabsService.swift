import Foundation
import Cocoa

/// Chrome 标签页信息
struct ChromeTab {
    let id: String              // 唯一标识: "windowIndex-tabIndex"
    let url: String             // 完整 URL
    let title: String           // 页面标题
    let windowIndex: Int        // 窗口索引（1-based）
    let tabIndex: Int           // 标签页索引（1-based）

    init(windowIndex: Int, tabIndex: Int, url: String, title: String) {
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.url = url
        self.title = title
        self.id = "\(windowIndex)-\(tabIndex)"
    }
}

/// Chrome 标签页服务
/// 负责获取和管理 Chrome 浏览器中已打开的标签页
class ChromeTabsService {
    static let shared = ChromeTabsService()

    private var tabsCache: [ChromeTab] = []
    private var refreshTimer: Timer?
    private let maxTabs = 200  // 最多缓存 200 个标签页

    private init() {
        log("🔒 ChromeTabsService 初始化...")
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
        log("🗑️ ChromeTabsService 释放")
    }

    // MARK: - 定时刷新

    /// 启动定时刷新器（每 10 秒）
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshTabs()
        }
        log("⏰ Chrome 标签页定时刷新已启动（每 10 秒）")
    }

    /// 刷新标签页列表
    func refreshTabs() {
        log("🔄 刷新 Chrome 标签页...")

        if let tabs = fetchChromeTabs() {
            let oldCount = tabsCache.count
            tabsCache = Array(tabs.prefix(maxTabs))
            let newCount = tabsCache.count
            log("✅ Chrome 标签页已刷新：旧 \(oldCount) 条 → 新 \(newCount) 条")
        } else {
            log("⚠️ 获取 Chrome 标签页失败（Chrome 可能未运行）", level: .warning)
        }
    }

    // MARK: - AppleScript 交互

    /// 通过 AppleScript 获取 Chrome 所有标签页
    private func fetchChromeTabs() -> [ChromeTab]? {
        let script = """
        tell application "System Events"
            set isRunning to (name of processes) contains "Google Chrome"
        end tell

        if isRunning then
            tell application id "com.google.Chrome"
                set tabList to {}
                set windowIndex to 1
                repeat with w in every window
                    set tabIndex to 1
                    repeat with t in every tab in w
                        set tabInfo to {windowIndex, tabIndex, URL of t, title of t}
                        set end of tabList to tabInfo
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowIndex to windowIndex + 1
                end repeat
                return tabList
            end tell
        else
            return missing value
        end if
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            log("❌ 创建 AppleScript 失败", level: .error)
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            log("❌ AppleScript 执行失败: \(error)", level: .error)
            return nil
        }

        // 解析返回结果
        return parseAppleScriptResult(result)
    }

    /// 解析 AppleScript 返回的结果
    private func parseAppleScriptResult(_ result: NSAppleEventDescriptor) -> [ChromeTab]? {
        // 检查是否返回了有效数据
        // descriptorType 为 0 表示没有数据或 Chrome 未运行
        guard result.descriptorType != 0 else {
            return nil
        }

        var tabs: [ChromeTab] = []

        // 遍历列表中的每一项
        // AppleScript 列表是 1-indexed，numberOfItems 返回实际数量
        let itemCount = result.numberOfItems
        for i in 1...itemCount {
            guard let item = result.atIndex(i) else { continue }

            // 每一项是一个包含 {windowIndex, tabIndex, url, title} 的列表
            guard item.numberOfItems == 4 else { continue }

            let windowIndex = item.atIndex(1)?.int32Value ?? 1
            let tabIndex = item.atIndex(2)?.int32Value ?? 1
            let url = item.atIndex(3)?.stringValue ?? ""
            let title = item.atIndex(4)?.stringValue ?? ""

            // 过滤掉无效的标签页
            if !url.isEmpty && !title.isEmpty {
                tabs.append(ChromeTab(
                    windowIndex: Int(windowIndex),
                    tabIndex: Int(tabIndex),
                    url: url,
                    title: title
                ))
            }
        }

        return tabs.isEmpty ? nil : tabs
    }

    /// 激活指定的标签页
    func activateTab(_ tab: ChromeTab) {
        log("🎯 激活 Chrome 标签: \(tab.title) (窗口 \(tab.windowIndex), 标签 \(tab.tabIndex))")

        let script = """
        tell application id "com.google.Chrome"
            activate
            set activeTab to tab \(tab.tabIndex) of window \(tab.windowIndex)
            set active tab index of window \(tab.windowIndex) to \(tab.tabIndex)
            set index of window \(tab.windowIndex) to 1
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            log("❌ 创建激活 AppleScript 失败", level: .error)
            return
        }

        appleScript.executeAndReturnError(&error)

        if let error = error {
            log("❌ 激活标签页失败: \(error)", level: .error)
            log("💡 标签页可能已关闭，将在下次刷新时更新缓存", level: .info)
        } else {
            log("✅ 标签页激活成功")
        }
    }

    // MARK: - 搜索接口

    /// 根据关键词搜索标签页（自动去重）
    func searchTabs(query: String) -> [ChromeTab] {
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        let keywords = lowercasedQuery.split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !keywords.isEmpty else { return [] }

        let matchedTabs = tabsCache.filter { tab in
            matchQuery(keywords: keywords, tab: tab)
        }

        // 基于 title + url 去重，只保留第一个
        var seen = Set<String>()
        return matchedTabs.filter { tab in
            let key = "\(tab.title)|\(tab.url)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    /// 检查标签页是否匹配查询关键词
    private func matchQuery(keywords: [String], tab: ChromeTab) -> Bool {
        let lowerTitle = tab.title.lowercased()
        let lowerUrl = tab.url.lowercased()

        // 所有关键词都必须匹配（AND 逻辑）
        for keyword in keywords {
            let titleMatch = singleKeywordMatch(keyword: keyword, target: lowerTitle)
            let urlMatch = singleKeywordMatch(keyword: keyword, target: lowerUrl)

            // 标题或 URL 任一匹配即可
            if !titleMatch && !urlMatch {
                return false
            }
        }

        return true
    }

    /// 单关键词匹配
    private func singleKeywordMatch(keyword: String, target: String) -> Bool {
        if target.isEmpty || keyword.isEmpty {
            return false
        }

        // 精确匹配
        if target == keyword {
            return true
        }

        // 前缀匹配
        if target.hasPrefix(keyword) {
            return true
        }

        // 包含匹配
        if target.contains(keyword) {
            return true
        }

        return false
    }

    // MARK: - 公共接口

    /// 获取当前缓存的标签页数量
    var cachedTabCount: Int {
        tabsCache.count
    }

    /// 通过 id 获取标签页
    func getTab(byId id: String) -> ChromeTab? {
        tabsCache.first { $0.id == id }
    }
}
