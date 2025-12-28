import Foundation
import Cocoa
import SQLite3

// 搜索结果类型
enum SearchResultType {
    case application
    case url
    case file
    case dictionary  // 词典翻译
    case ideProject  // IDE 项目
}

// 搜索结果
struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let path: String
    let type: SearchResultType
    let icon: NSImage?
    let score: Double // 匹配分数
}

// 搜索引擎
class SearchEngine {
    private let configManager: ConfigManager
    private var applicationCache: [ApplicationInfo] = []
    private var browserHistoryCache: [BrowserHistoryItem] = []
    private var browserBookmarksCache: [BrowserBookmarkItem] = []
    private var historyRefreshTimer: Timer?  // 历史记录刷新定时器
    private var lastHistoryLoadTime: Date?   // 上次加载历史的时间
    
    // 性能优化：缓存上次搜索结果
    private var lastQuery: String = ""
    private var lastResults: [SearchResult] = []
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
        log("🎉 SearchEngine 初始化开始...")
        
        log("📱 加载应用程序...")
        loadApplications()
        log("✅ 应用程序加载完成，共 \(applicationCache.count) 个")
        
        // 加载 Chrome 书签
        log("📚 加载 Chrome 书签...")
        loadChromeBookmarks()
        log("✅ Chrome 书签加载完成，共 \(browserBookmarksCache.count) 条")
        
        // 加载 Chrome 历史（需要权限）
        log("📊 检查浏览器历史配置...")
        log("❓ browserHistoryEnabled = \(configManager.browserHistoryEnabled)")
        
        if configManager.browserHistoryEnabled {
            log("✅ 浏览器历史已启用，开始加载...")
            loadBrowserHistory()
            log("✅ 浏览器历史加载完成，共 \(browserHistoryCache.count) 条")
            
            // 启动定时器，每 30 秒刷新一次历史记录
            startHistoryRefreshTimer()
        } else {
            log("⚠️ 浏览器历史未启用", level: .warning)
        }
        
        log("✅ SearchEngine 初始化完成")
        log("📊 总计: 应用 \(applicationCache.count) 个, 书签 \(browserBookmarksCache.count) 条, 历史 \(browserHistoryCache.count) 条")
    }
    
    deinit {
        // 清理定时器
        historyRefreshTimer?.invalidate()
        historyRefreshTimer = nil
        log("🗑️ SearchEngine 释放，已停止定时器")
    }
    
    // MARK: - 后缀过滤器
    
    /// 搜索过滤器类型
    enum SearchFilter {
        case all                    // 无过滤，搜索所有
        case ideProject(IDEConfig)  // IDE 项目（带配置对象）
        case application            // 应用程序 (ap)
        case chromeBookmark         // Chrome 书签 (ch)
        case chromeHistory          // Chrome 历史 (hi)
        case dictionary             // 词典 (di)
    }
    
    /// 解析查询字符串，提取关键词和过滤器
    private func parseQuery(_ query: String) -> (keyword: String, filter: SearchFilter) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        
        // 优先检查是否包含 IDE 关键词（支持前缀/后缀）
        if let ideMatch = IDEProjectService.shared.parseIDEPrefix(query: trimmed) {
            return (ideMatch.keyword, .ideProject(ideMatch.config))
        }
        
        // 其他魔法后缀匹配
        let parts = trimmed.split(separator: " ").map { String($0) }
        
        guard parts.count >= 2 else {
            return (trimmed, .all)
        }
        
        // 检查最后一个部分是否是过滤后缀
        let lastPart = parts.last!.lowercased()
        let keyword = parts.dropLast().joined(separator: " ")
        
        switch lastPart {
        case "ap":
            return (keyword, .application)
        case "ch":
            return (keyword, .chromeBookmark)
        case "hi":
            return (keyword, .chromeHistory)
        case "di":
            return (keyword, .dictionary)
        default:
            return (trimmed, .all)
        }
    }
    
    func search(query: String) async -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        // 性能优化：如果查询没变，直接返回缓存结果
        if query == lastQuery {
            return lastResults
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 解析查询，提取关键词和过滤器
        let (keyword, filter) = parseQuery(query)
        
        var combined: [SearchResult] = []
        
        switch filter {
        case .all:
            // 搜索所有类型
            let appResults = searchApplications(query: keyword)
            let dictResults = await searchDictionary(query: keyword)
            let ideProjectResults = searchAllIDEProjects(query: keyword)
            let bookmarkResults = searchChromeBookmarks(query: keyword)
            let historyResults = configManager.browserHistoryEnabled ? searchBrowserHistory(query: keyword) : []
            combined = appResults + dictResults + ideProjectResults + bookmarkResults + historyResults
            
        case .ideProject(let config):
            // 只搜索指定 IDE 的项目
            combined = searchIDEProjects(keyword: keyword, config: config)
            
        case .application:
            // 只搜索应用程序
            combined = searchApplications(query: keyword)
            
        case .chromeBookmark:
            // 只搜索 Chrome 书签
            combined = searchChromeBookmarks(query: keyword)
            
        case .chromeHistory:
            // 只搜索 Chrome 历史
            combined = configManager.browserHistoryEnabled ? searchBrowserHistory(query: keyword) : []
            
        case .dictionary:
            // 只搜索词典
            combined = await searchDictionary(query: keyword)
        }
        
        // 去重：相同 path 只保留一个
        var seenPaths = Set<String>()
        let uniqueResults = combined.filter { result in
            if seenPaths.contains(result.path) {
                return false
            }
            seenPaths.insert(result.path)
            return true
        }
        
        // 关键修复：完全不匹配（分数=0）的结果直接过滤掉
        let matchedResults = uniqueResults.filter { $0.score > 0 }
        
        // 智能排序：结合匹配分数、类型优先级和使用历史
        let sorted = matchedResults.sorted { a, b in
            // 性能优化：只对高分匹配的结果计算使用权重，避免不必要的计算
            let highScoreThreshold = 50.0
            let aIsHighScore = a.score >= highScoreThreshold
            let bIsHighScore = b.score >= highScoreThreshold
            
            // 如果只有一个高分匹配，优先显示它
            if aIsHighScore && !bIsHighScore {
                return true
            }
            if !aIsHighScore && bIsHighScore {
                return false
            }
            
            // 两个都是高分匹配，考虑使用历史
            if aIsHighScore && bIsHighScore {
                // 获取使用权重
                let aWeight = UsageHistory.shared.getUsageWeight(path: a.path)
                let bWeight = UsageHistory.shared.getUsageWeight(path: b.path)
                
                // 如果使用权重差异较大，优先按权重排序
                if abs(aWeight - bWeight) > 1.0 {
                    return aWeight > bWeight
                }
                
                // 否则按类型优先级
                let aTypePriority = typePriority(a.type)
                let bTypePriority = typePriority(b.type)
                
                if aTypePriority != bTypePriority {
                    return aTypePriority < bTypePriority
                }
                
                // 同类型下，按匹配分数
                return a.score > b.score
            }
            
            // 两个都是低分匹配，直接按分数排序，忽略使用历史
            if a.score != b.score {
                return a.score > b.score
            }
            
            // 分数相同，按类型优先级
            let aTypePriority = typePriority(a.type)
            let bTypePriority = typePriority(b.type)
            return aTypePriority < bTypePriority
        }
        
        let results = Array(sorted.prefix(10))
        
        // 缓存结果
        lastQuery = query
        lastResults = results
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        log("⏱️ 搜索耗时: \(String(format: "%.2f", elapsed))ms, 结果: \(results.count) 条")
        
        return results
    }
    
    // 类型优先级：数字越小优先级越高
    private func typePriority(_ type: SearchResultType) -> Int {
        switch type {
        case .application: return 1
        case .ideProject: return 1  // IDE 项目与应用同级
        case .dictionary: return 2  // 词典翻译
        case .url: return 3  // 书签和历史都是 url
        case .file: return 4
        }
    }
    
    // MARK: - IDE 项目搜索
    
    /// 搜索所有 IDE 的项目（常规搜索，不需要魔法前缀）
    private func searchAllIDEProjects(query: String) -> [SearchResult] {
        let projects = IDEProjectService.shared.searchAllProjects(keyword: query)
        
        return projects.map { project in
            // 计算分数：IDE项目给予较高分数
            let score = 85.0  // 与应用程序类似的高分
            
            return SearchResult(
                title: "[\(project.ideName)] \(project.name)",
                subtitle: project.path,
                path: "ide://\(project.prefix)/\(project.path)",  // 使用 prefix 构建路径
                type: .ideProject,
                icon: project.appIcon,
                score: score
            )
        }
    }
    
    /// 搜索指定 IDE 的项目（魔法关键词搜索）
    private func searchIDEProjects(keyword: String, config: IDEConfig) -> [SearchResult] {
        let projects = IDEProjectService.shared.searchProjects(keyword: keyword, config: config)
        
        return projects.enumerated().map { index, project in
            // 计算分数：按顺序递减，第一个最高分
            let score = 100.0 - Double(index)
            
            return SearchResult(
                title: "[\(config.name)] \(project.name)",
                subtitle: project.path,
                path: "ide://\(config.primaryPrefix)/\(project.path)",  // 特殊协议标记
                type: .ideProject,
                icon: project.appIcon,  // 使用 IDE 应用本身的图标
                score: score
            )
        }
    }
    
    // MARK: - 词典搜索
    
    private func searchDictionary(query: String) async -> [SearchResult] {
        // 判断是否为英文单词
        guard DictionaryService.shared.isEnglishWord(query) else {
            return []
        }
        
        // 查询系统词典
        guard let entry = await DictionaryService.shared.lookup(word: query) else {
            return []
        }
        
        // 构造搜索结果
        return [SearchResult(
            title: entry.word,
            subtitle: entry.shortTranslation,
            path: "dict://\(entry.word)",  // 使用特殊协议标记词典结果
            type: .dictionary,
            icon: NSImage(systemSymbolName: "book.closed", accessibilityDescription: "词典"),
            score: 95.0  // 高分，但不超过精确匹配的应用
        )]
    }
    
    // MARK: - 应用程序搜索
    
    private func loadApplications() {
        let fileManager = FileManager.default
        let applicationsPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications"
        ]
        
        for path in applicationsPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (path as NSString).appendingPathComponent(item)
                if let appInfo = ApplicationInfo.from(path: fullPath) {
                    applicationCache.append(appInfo)
                }
            }
        }
    }
    
    private func searchApplications(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        
        return applicationCache.compactMap { app in
            let score = fuzzyMatch(query: lowercasedQuery, target: app.name.lowercased())
            
            guard score > 0 else { return nil }
            
            return SearchResult(
                title: app.name,
                subtitle: app.path,
                path: app.path,
                type: .application,
                icon: app.icon,
                score: score
            )
        }
    }
    
    // MARK: - 浏览器历史搜索
    
    // 启动定时器，定期刷新历史记录
    private func startHistoryRefreshTimer() {
        // 每 30 秒刷新一次
        historyRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshBrowserHistory()
        }
        log("⏰ 历史记录定时刷新已启动（每 30 秒）")
    }
    
    // 刷新浏览器历史（增量或全量）
    private func refreshBrowserHistory() {
        log("🔄 刷新浏览器历史...")
        let oldCount = browserHistoryCache.count
        
        // 防御性检查：如果累加过多，警告并重置
        if oldCount > 10000 {
            log("⚠️ 检测到异常大量历史记录 (\(oldCount) 条)，重置缓存...", level: .warning)
            browserHistoryCache.removeAll()
        }
        
        loadChromeHistory()  // 重新加载
        let newCount = browserHistoryCache.count
        log("✅ 历史记录已刷新：旧 \(oldCount) 条 → 新 \(newCount) 条")
        
        // 防御性检查：如果新数据异常，警告
        if newCount > 1000 {
            log("⚠️ 刷新后历史记录数量异常 (\(newCount) 条)，预期为 500 条", level: .warning)
        }
    }
    
    // 将 Chrome 时间戳转换为 Swift Date
    // Chrome 使用从 1601-01-01 00:00:00 UTC 开始的微秒数
    private func convertChromeTimeToDate(_ chromeTime: Int64) -> Date {
        // 1601-01-01 到 1970-01-01 的微秒数
        let epochDifference: Int64 = 11644473600000000
        let unixTimeMicros = chromeTime - epochDifference
        let unixTimeSeconds = Double(unixTimeMicros) / 1_000_000.0
        return Date(timeIntervalSince1970: unixTimeSeconds)
    }
    
    private func loadBrowserHistory() {
        // 仅加载 Chrome 历史
        log("📚 开始加载浏览器历史...")
        loadChromeHistory()
        log("✅ 浏览器历史加载完成，共 \(browserHistoryCache.count) 条记录")
    }
    
    private func loadChromeHistory() {
        let historyPath = NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/History"
        
        log("📚 尝试加载 Chrome 历史...")
        log("📋 历史路径: \(historyPath)")
        
        // 检查文件是否存在
        let fileExists = FileManager.default.fileExists(atPath: historyPath)
        log("❓ 文件存在: \(fileExists)")
        
        if !fileExists {
            log("⚠️ Chrome 历史文件不存在", level: .warning)
            return
        }
        
        // 尝试方法1: 使用 shell 命令复制（绕过沙盒限制）
        let tempPath = NSTemporaryDirectory() + "chrome_history_\(UUID().uuidString).db"
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/cp")
            process.arguments = [historyPath, tempPath]
            
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                log("✅ 通过 shell 命令成功复制历史数据库")
                defer { try? FileManager.default.removeItem(atPath: tempPath) }
                
                if let db = openSQLiteDatabase(path: tempPath) {
                    let query = """
                        SELECT url, title, visit_count, last_visit_time
                        FROM urls
                        ORDER BY last_visit_time DESC
                        LIMIT 500
                    """
                    
                    let items = executeSQLQuery(db: db, query: query) { row in
                        // Chrome 的 last_visit_time 是从 1601-01-01 开始的微秒数
                        let chromeTimestamp = row[3] as? Int64 ?? 0
                        let appleTimestamp = convertChromeTimeToDate(chromeTimestamp)
                        
                        return BrowserHistoryItem(
                            url: row[0] as? String ?? "",
                            title: row[1] as? String ?? "",
                            visitCount: row[2] as? Int ?? 0,
                            lastVisitTime: appleTimestamp,
                            source: .chrome
                        )
                    }
                    
                    browserHistoryCache = items  // 替换整个缓存
                    lastHistoryLoadTime = Date()  // 记录加载时间
                    closeSQLiteDatabase(db)
                    log("✅ Chrome 历史加载完成，共 \(items.count) 条记录")
                    return
                } else {
                    log("❌ 无法打开 Chrome 历史数据库", level: .error)
                }
            } else {
                log("⚠️ shell 命令执行失败，尝试直接复制...", level: .warning)
            }
        } catch {
            log("⚠️ shell 命令执行出错: \(error.localizedDescription)", level: .warning)
        }
        
        // 尝试方法2: 直接复制（需要完全磁盘访问权限）
        let fileURL = URL(fileURLWithPath: historyPath)
        
        var isAccessing = false
        if fileURL.startAccessingSecurityScopedResource() {
            isAccessing = true
            log("✅ 获取安全作用域访问权限")
        }
        
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try FileManager.default.copyItem(at: fileURL, to: URL(fileURLWithPath: tempPath))
            log("✅ 成功复制历史数据库到临时目录")
            defer { try? FileManager.default.removeItem(atPath: tempPath) }
            
            if let db = openSQLiteDatabase(path: tempPath) {
                let query = """
                    SELECT url, title, visit_count, last_visit_time
                    FROM urls
                    ORDER BY visit_count DESC, last_visit_time DESC
                    LIMIT 500
                """
                
                let items = executeSQLQuery(db: db, query: query) { row in
                    let lastVisitTimeValue = row[3] as? Int64 ?? 0
                    let lastVisitDate = Date(timeIntervalSince1970: Double(lastVisitTimeValue) / 1000000.0 - 11644473600.0)
                    return BrowserHistoryItem(
                        url: row[0] as? String ?? "",
                        title: row[1] as? String ?? "",
                        visitCount: row[2] as? Int ?? 0,
                        lastVisitTime: lastVisitDate,
                        source: .chrome
                    )
                }
                
                browserHistoryCache = items  // 修复：替换而非累加
                lastHistoryLoadTime = Date()  // 记录加载时间
                closeSQLiteDatabase(db)
                log("✅ Chrome 历史加载完成，共 \(items.count) 条记录")
            } else {
                log("❌ 无法打开 Chrome 历史数据库", level: .error)
            }
        } catch let error as NSError {
            log("❌ 无法访问 Chrome 历史: \(error.localizedDescription)", level: .error)
            log("💡 错误代码: \(error.domain) - \(error.code)", level: .debug)
            
            if error.code == 257 || error.code == 1 {
                log("🔒 权限被拒绝！", level: .error)
                log("💡 解决方法:", level: .warning)
                log("   1. 系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Spotlight", level: .warning)
                log("   2. 添加后需要 **完全退出并重启** 应用", level: .warning)
                log("   3. 如果仍然失败，请尝试: killall Spotlight && open ~/Applications/Spotlight.app", level: .warning)
            }
        }
    }
    
    // Safari 历史支持已移除，仅支持 Chrome
    
    // 加载 Chrome 书签（从导出的 HTML 文件）
    private func loadChromeBookmarks() {
        let bookmarksDir = NSHomeDirectory() + "/Documents/Spotlight"
        log("📚 尝试加载 Chrome 书签...")
        log("📋 书签目录: \(bookmarksDir)")
        
        // 检查目录是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bookmarksDir) else {
            log("⚠️ 书签目录不存在: \(bookmarksDir)", level: .warning)
            log("💡 请创建目录并导出 Chrome 书签到此目录", level: .info)
            return
        }
        
        // 查找最新的书签文件（格式：bookmarks_YYYY_MM_DD.html）
        do {
            let files = try fileManager.contentsOfDirectory(atPath: bookmarksDir)
            let bookmarkFiles = files.filter { $0.hasPrefix("bookmarks_") && $0.hasSuffix(".html") }
            
            if bookmarkFiles.isEmpty {
                log("⚠️ 未找到书签文件（格式: bookmarks_YYYY_MM_DD.html）", level: .warning)
                return
            }
            
            // 按文件名排序，取最新的
            let sortedFiles = bookmarkFiles.sorted(by: >)
            let latestFile = sortedFiles[0]
            let filePath = (bookmarksDir as NSString).appendingPathComponent(latestFile)
            
            log("📄 找到最新书签文件: \(latestFile)")
            
            // 读取并解析 HTML 文件
            let htmlContent = try String(contentsOfFile: filePath, encoding: .utf8)
            log("✅ 成功读取书签文件，大小: \(htmlContent.count) 字符")
            
            // 解析 HTML 提取书签
            parseHTMLBookmarks(html: htmlContent)
            
            log("✅ Chrome 书签加载完成，共 \(browserBookmarksCache.count) 条记录")
        } catch {
            log("❌ 读取书签文件失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    // 解析 HTML 格式的书签文件
    private func parseHTMLBookmarks(html: String) {
        // Chrome 导出的书签格式: <A HREF="url" ...>title</A>
        let pattern = #"<A HREF="([^"]+)"[^>]*>([^<]+)</A>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            log("❌ 正则表达式创建失败", level: .error)
            return
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        log("🔍 正在解析书签... 找到 \(matches.count) 个匹配项")
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let urlRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            
            let url = nsString.substring(with: urlRange)
            let title = nsString.substring(with: titleRange)
            
            // 过滤掉空白和无效的书签
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmedTitle.isEmpty && !trimmedUrl.isEmpty {
                browserBookmarksCache.append(BrowserBookmarkItem(
                    url: trimmedUrl,
                    title: trimmedTitle,
                    source: .chrome
                ))
            }
        }
    }
    
    // 搜索 Chrome 书签
    private func searchChromeBookmarks(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        return browserBookmarksCache.compactMap { item in
            let titleScore = fuzzyMatch(query: lowercasedQuery, target: item.title.lowercased())
            let urlScore = fuzzyMatch(query: lowercasedQuery, target: item.url.lowercased())
            let score = max(titleScore, urlScore)
            guard score > 0 else { return nil }
            return SearchResult(
                title: item.title.isEmpty ? item.url : item.title,
                subtitle: item.url,
                path: item.url,
                type: .url,
                icon: NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app"),
                score: score
            )
        }
    }
    
    private func searchBrowserHistory(query: String) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        let now = Date()
        
        return browserHistoryCache.compactMap { item in
            let titleScore = fuzzyMatch(query: lowercasedQuery, target: item.title.lowercased())
            let urlScore = fuzzyMatch(query: lowercasedQuery, target: item.url.lowercased())
            let baseScore = max(titleScore, urlScore)
            
            guard baseScore > 0 else { return nil }
            
            // 性能优化：简化权重计算
            // 计算时间权重：越近访问的权重越高
            let daysSinceVisit = now.timeIntervalSince(item.lastVisitTime) / 86400.0
            let timeWeight = daysSinceVisit < 7 ? 1.3 : 1.0  // 简化：7天内1.3倍，其他正常
            
            // 计算访问次数权重：简化计算
            let visitWeight = item.visitCount > 10 ? 1.2 : 1.0  // 简化：访问超过10次给1.2倍
            
            // 综合分数
            let finalScore = baseScore * timeWeight * visitWeight
            
            return SearchResult(
                title: item.title.isEmpty ? item.url : item.title,
                subtitle: item.url,
                path: item.url,
                type: .url,
                icon: item.source == .chrome ? 
                    NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app") :
                    NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"),
                score: finalScore
            )
        }
    }
    
    // MARK: - 模糊匹配算法
    
    /// 多关键词模糊匹配（AND 逻辑）
    /// 查询字符串按空格分割成多个关键词，所有关键词都必须匹配才返回有效分数
    private func multiKeywordFuzzyMatch(query: String, target: String) -> Double {
        guard !query.isEmpty, !target.isEmpty else { return 0 }
        
        let lowercasedTarget = target.lowercased()
        
        // 按空格分割关键词，过滤空字符串
        let keywords = query.lowercased()
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // 如果没有有效关键词，返回 0
        guard !keywords.isEmpty else { return 0 }
        
        // 单关键词时，使用原有逻辑
        if keywords.count == 1 {
            return singleKeywordMatch(query: keywords[0], target: lowercasedTarget)
        }
        
        // 多关键词时，所有关键词都必须匹配（AND 逻辑）
        var scores: [Double] = []
        
        for keyword in keywords {
            let score = singleKeywordMatch(query: keyword, target: lowercasedTarget)
            if score <= 0 {
                // 任一关键词不匹配，直接返回 0
                return 0
            }
            scores.append(score)
        }
        
        // 返回所有关键词匹配分数的最小值（短板原理）
        // 同时给予少量加分，奖励多关键词匹配
        let minScore = scores.min() ?? 0
        let matchBonus = Double(keywords.count - 1) * 2.0  // 每多一个关键词加 2 分
        
        return min(minScore + matchBonus, 100.0)
    }
    
    /// 单关键词匹配（严格子串匹配）
    private func singleKeywordMatch(query: String, target: String) -> Double {
        guard !query.isEmpty, !target.isEmpty else { return 0 }
        
        // 精确匹配
        if target == query {
            return 100.0
        }
        
        // 前缀匹配
        if target.hasPrefix(query) {
            return 90.0
        }
        
        // 包含匹配（关键词必须作为完整子串出现）
        if target.contains(query) {
            return 80.0
        }
        
        // 不再支持逐字符匹配，避免误匹配
        // 例如 "wlcb" 不应该匹配到散落的 w, l, c, b 字母
        return 0
    }
    
    /// 保留原有 fuzzyMatch 接口，现在支持多关键词
    private func fuzzyMatch(query: String, target: String) -> Double {
        return multiKeywordFuzzyMatch(query: query, target: target)
    }
    
    // MARK: - SQLite 辅助方法
    
    private func openSQLiteDatabase(path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            return db
        }
        return nil
    }
    
    private func closeSQLiteDatabase(_ db: OpaquePointer) {
        sqlite3_close(db)
    }
    
    private func executeSQLQuery<T>(db: OpaquePointer, query: String, rowMapper: ([Any?]) -> T) -> [T] {
        var results: [T] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [Any?] = []
                let columnCount = sqlite3_column_count(statement)
                
                for i in 0..<columnCount {
                    let type = sqlite3_column_type(statement, i)
                    switch type {
                    case SQLITE_INTEGER:
                        row.append(Int(sqlite3_column_int64(statement, i)))
                    case SQLITE_TEXT:
                        if let cString = sqlite3_column_text(statement, i) {
                            row.append(String(cString: cString))
                        } else {
                            row.append(nil)
                        }
                    default:
                        row.append(nil)
                    }
                }
                
                results.append(rowMapper(row))
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
}

// MARK: - 辅助数据结构

struct ApplicationInfo {
    let name: String
    let path: String
    let bundleIdentifier: String?
    let icon: NSImage?
    
    static func from(path: String) -> ApplicationInfo? {
        let url = URL(fileURLWithPath: path)
        guard let bundle = Bundle(url: url) else { return nil }
        
        let name = bundle.infoDictionary?["CFBundleName"] as? String ?? 
                   url.deletingPathExtension().lastPathComponent
        let bundleID = bundle.bundleIdentifier
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        return ApplicationInfo(
            name: name,
            path: path,
            bundleIdentifier: bundleID,
            icon: icon
        )
    }
}

enum BrowserSource {
    case chrome
    // Safari 支持已移除
}

struct BrowserBookmarkItem {
    let url: String
    let title: String
    let source: BrowserSource
}

struct BrowserHistoryItem {
    let url: String
    let title: String
    let visitCount: Int
    let lastVisitTime: Date  // 最后访问时间
    let source: BrowserSource
}
