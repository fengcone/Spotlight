import Foundation
import Cocoa
import SQLite3

// 搜索结果类型
enum SearchResultType {
    case application
    case url
    case file
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
        } else {
            log("⚠️ 浏览器历史未启用", level: .warning)
        }
        
        log("✅ SearchEngine 初始化完成")
        log("📊 总计: 应用 \(applicationCache.count) 个, 书签 \(browserBookmarksCache.count) 条, 历史 \(browserHistoryCache.count) 条")
    }
    
    func search(query: String) async -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        // 按优先级分别搜索
        let appResults = searchApplications(query: query)
        let bookmarkResults = searchChromeBookmarks(query: query)
        let historyResults = configManager.browserHistoryEnabled ? searchBrowserHistory(query: query) : []
        
        // 合并所有结果
        let combined = appResults + bookmarkResults + historyResults
        
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
            // 获取使用权重
            let aWeight = UsageHistory.shared.getUsageWeight(path: a.path)
            let bWeight = UsageHistory.shared.getUsageWeight(path: b.path)
            
            // 分数越高，匹配度越好
            // 80-100: 包含/前缀/精确匹配
            // 1-70: 逼字符匹配
            
            // 关键策略：只有当两个都是高分匹配（>= 50）时，才考虑使用历史
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
        
        return Array(sorted.prefix(10))
    }
    
    // 类型优先级：数字越小优先级越高
    private func typePriority(_ type: SearchResultType) -> Int {
        switch type {
        case .application: return 1
        case .url: return 2  // 书签和历史都是 url
        case .file: return 3
        }
    }
    
    // MARK: - 应用程序搜索
    
    private func loadApplications() {
        let fileManager = FileManager.default
        let applicationsPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
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
                        ORDER BY visit_count DESC, last_visit_time DESC
                        LIMIT 500
                    """
                    
                    let items = executeSQLQuery(db: db, query: query) { row in
                        BrowserHistoryItem(
                            url: row[0] as? String ?? "",
                            title: row[1] as? String ?? "",
                            visitCount: row[2] as? Int ?? 0,
                            source: .chrome
                        )
                    }
                    
                    browserHistoryCache.append(contentsOf: items)
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
                    BrowserHistoryItem(
                        url: row[0] as? String ?? "",
                        title: row[1] as? String ?? "",
                        visitCount: row[2] as? Int ?? 0,
                        source: .chrome
                    )
                }
                
                browserHistoryCache.append(contentsOf: items)
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
        
        return browserHistoryCache.compactMap { item in
            let titleScore = fuzzyMatch(query: lowercasedQuery, target: item.title.lowercased())
            let urlScore = fuzzyMatch(query: lowercasedQuery, target: item.url.lowercased())
            let score = max(titleScore, urlScore) * (1 + log10(Double(item.visitCount + 1)))
            
            guard score > 0 else { return nil }
            
            return SearchResult(
                title: item.title.isEmpty ? item.url : item.title,
                subtitle: item.url,
                path: item.url,
                type: .url,
                icon: item.source == .chrome ? 
                    NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app") :
                    NSWorkspace.shared.icon(forFile: "/Applications/Safari.app"),
                score: score
            )
        }
    }
    
    // MARK: - 模糊匹配算法
    
    private func fuzzyMatch(query: String, target: String) -> Double {
        guard !query.isEmpty, !target.isEmpty else { return 0 }
        
        // 精确匹配
        if target == query {
            return 100.0
        }
        
        // 前缀匹配
        if target.hasPrefix(query) {
            return 90.0
        }
        
        // 包含匹配
        if target.contains(query) {
            return 80.0
        }
        
        // 逐字符匹配（用于首字母缩写等）
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        var matchCount = 0
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                matchCount += 1
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        if matchCount == query.count {
            return Double(matchCount) / Double(target.count) * 70.0
        }
        
        return 0
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
    let source: BrowserSource
}
