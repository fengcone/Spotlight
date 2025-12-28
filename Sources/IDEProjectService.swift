import Foundation
import AppKit
import SQLite3

// MARK: - 数据结构

/// IDE 配置
struct IDEConfig: Codable {
    let name: String
    let prefixes: [String]    // 支持多个关键词（前缀/后缀）
    let type: String           // "jetbrains" 或 "vscode"
    let appPath: String        // IDE 应用路径，用于获取图标
    let recentProjectsPath: String
    let urlScheme: String
    let enabled: Bool
    
    // 为了向后兼容，支持从旧配置读取 prefix
    enum CodingKeys: String, CodingKey {
        case name, prefixes, prefix, type, appPath, recentProjectsPath, urlScheme, enabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        appPath = try container.decode(String.self, forKey: .appPath)
        recentProjectsPath = try container.decode(String.self, forKey: .recentProjectsPath)
        urlScheme = try container.decode(String.self, forKey: .urlScheme)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        
        // 优先读取 prefixes 数组，如果没有则读取旧的 prefix
        if let prefixesArray = try? container.decode([String].self, forKey: .prefixes) {
            prefixes = prefixesArray
        } else if let singlePrefix = try? container.decode(String.self, forKey: .prefix) {
            prefixes = [singlePrefix]
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                    debugDescription: "无法找到 prefixes 或 prefix 字段")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(prefixes, forKey: .prefixes)
        try container.encode(type, forKey: .type)
        try container.encode(appPath, forKey: .appPath)
        try container.encode(recentProjectsPath, forKey: .recentProjectsPath)
        try container.encode(urlScheme, forKey: .urlScheme)
        try container.encode(enabled, forKey: .enabled)
    }
    
    /// 获取主关键词（用于缓存键和路径构建）
    var primaryPrefix: String {
        return prefixes.first ?? "unknown"
    }
}

/// IDE 配置文件根结构
struct IDEConfigFile: Codable {
    let ides: [IDEConfig]
}

/// IDE 项目信息
struct IDEProject {
    let name: String           // 项目名称
    let path: String           // 项目完整路径
    let ideName: String        // IDE 名称
    let prefix: String         // IDE 前缀（用于路径构建）
    let appPath: String        // IDE 应用路径
    let urlScheme: String      // 打开 URL
    let appIcon: NSImage?      // IDE 应用图标
}

// MARK: - IDE 项目服务

class IDEProjectService {
    static let shared = IDEProjectService()
    
    private var ideConfigs: [IDEConfig] = []
    private var projectCache: [String: [IDEProject]] = [:]  // prefix -> projects
    private let cacheQueue = DispatchQueue(label: "com.spotlight.ideproject.cache")
    
    private init() {
        loadConfig()
    }
    
    // MARK: - 配置加载
    
    /// 加载 IDE 配置文件
    private func loadConfig() {
        // 配置文件搜索路径（按优先级排序）
        var configPaths: [String] = []
        
        // 1. 应用包 Resources 目录（打包后的标准位置）
        if let resourcePath = Bundle.main.resourcePath {
            configPaths.append(resourcePath + "/ide_config.json")
        }
        
        // 2. 应用包同级目录
        configPaths.append(Bundle.main.bundlePath + "/../ide_config.json")
        
        // 3. 开发时工作目录
        configPaths.append(FileManager.default.currentDirectoryPath + "/ide_config.json")
        
        // 4. 用户配置目录
        configPaths.append(NSHomeDirectory() + "/.spotlight/ide_config.json")
        
        for path in configPaths {
            log("🔍 尝试加载 IDE 配置: \(path)")
            if let data = FileManager.default.contents(atPath: path) {
                do {
                    let config = try JSONDecoder().decode(IDEConfigFile.self, from: data)
                    ideConfigs = config.ides.filter { $0.enabled }
                    log("✅ IDE 配置加载成功: \(path)")
                    log("   支持的 IDE: \(ideConfigs.map { "\($0.primaryPrefix):\($0.name) (\($0.prefixes.joined(separator: ",")))" }.joined(separator: ", "))")
                    return
                } catch {
                    log("⚠️ IDE 配置解析失败: \(error)", level: .warning)
                }
            }
        }
        
        log("⚠️ 未找到 ide_config.json 配置文件", level: .warning)
        log("   已搜索路径: \(configPaths.joined(separator: ", "))", level: .warning)
    }
    
    /// 重新加载配置
    func reloadConfig() {
        loadConfig()
        projectCache.removeAll()
    }
    
    // MARK: - 配置获取
    
    /// 根据关键词获取 IDE 配置（支持前缀/后缀匹配）
    func getConfig(for keyword: String) -> IDEConfig? {
        let lowerKeyword = keyword.lowercased()
        return ideConfigs.first(where: { config in
            config.prefixes.contains(where: { $0.lowercased() == lowerKeyword })
        })
    }
    
    // MARK: - 前缀/后缀匹配
    
    /// 检查查询是否包含 IDE 关键词（支持前缀/后缀）
    /// - Returns: (匹配的关键词, 搜索关键词, 配置) 或 nil
    func parseIDEPrefix(query: String) -> (matchedKeyword: String, keyword: String, config: IDEConfig)? {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let parts = trimmed.split(separator: " ").map { String($0) }
        
        guard !parts.isEmpty else { return nil }
        
        for config in ideConfigs {
            for prefix in config.prefixes {
                let lowerPrefix = prefix.lowercased()
                
                // 情兵1: 前缀匹配 - "前缀 关键词"
                if parts.count >= 2 && parts[0] == lowerPrefix {
                    let keyword = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    return (lowerPrefix, keyword, config)
                }
                
                // 情兵2: 后缀匹配 - "关键词 后缀"
                if parts.count >= 2 && parts.last == lowerPrefix {
                    let keyword = parts.dropLast().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    return (lowerPrefix, keyword, config)
                }
                
                // 情兵3: 只输入关键词（显示所有项目）
                if parts.count == 1 && parts[0] == lowerPrefix {
                    return (lowerPrefix, "", config)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 项目搜索
    
    /// 搜索所有 IDE 的项目（用于常规搜索，不需要魔法前缀）
    func searchAllProjects(keyword: String) -> [IDEProject] {
        guard !keyword.isEmpty else { return [] }
        
        var allMatched: [IDEProject] = []
        let lowercasedKeyword = keyword.lowercased()
        
        for config in ideConfigs {
            let projects = getProjects(for: config)
            let matched = projects.filter { project in
                project.name.lowercased().contains(lowercasedKeyword) ||
                project.path.lowercased().contains(lowercasedKeyword)
            }
            allMatched.append(contentsOf: matched)
        }
        
        // 限制返回数量
        return Array(allMatched.prefix(10))
    }

    /// 搜索指定 IDE 的项目（用于魔法关键词搜索）
    func searchProjects(keyword: String, config: IDEConfig) -> [IDEProject] {
        // 获取或加载项目列表
        let projects = getProjects(for: config)
        
        // 如果没有关键词，返回所有项目
        if keyword.isEmpty {
            return Array(projects.prefix(20))
        }
        
        // 模糊匹配
        let lowercasedKeyword = keyword.lowercased()
        let matched = projects.filter { project in
            project.name.lowercased().contains(lowercasedKeyword) ||
            project.path.lowercased().contains(lowercasedKeyword)
        }
        
        return Array(matched.prefix(20))
    }
    
    /// 获取指定 IDE 的项目列表
    private func getProjects(for config: IDEConfig) -> [IDEProject] {
        let cacheKey = config.primaryPrefix
        
        // 检查缓存
        if let cached = cacheQueue.sync(execute: { projectCache[cacheKey] }) {
            return cached
        }
        
        // 解析最近项目文件
        let projects = parseRecentProjects(config: config)
        
        // 缓存结果
        cacheQueue.async { [weak self] in
            self?.projectCache[cacheKey] = projects
        }
        
        return projects
    }
    
    /// 解析最近项目（根据类型选择解析方式）
    private func parseRecentProjects(config: IDEConfig) -> [IDEProject] {
        switch config.type {
        case "vscode":
            return parseVSCodeProjects(config: config)
        case "jetbrains":
            return parseJetBrainsProjects(config: config)
        default:
            log("⚠️ 未知的 IDE 类型: \(config.type)", level: .warning)
            return []
        }
    }
    
    /// 解析 VS Code 系的 state.vscdb (SQLite 数据库)
    private func parseVSCodeProjects(config: IDEConfig) -> [IDEProject] {
        let expandedPath = (config.recentProjectsPath as NSString).expandingTildeInPath
        
        log("📂 解析 \(config.name) 最近项目 (VS Code SQLite): \(expandedPath)")
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            log("⚠️ 文件不存在: \(expandedPath)", level: .warning)
            return []
        }
        
        var projects: [IDEProject] = []
        var db: OpaquePointer?
        
        // 打开数据库
        guard sqlite3_open_v2(expandedPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            log("⚠️ 无法打开数据库: \(expandedPath)", level: .warning)
            return []
        }
        defer { sqlite3_close(db) }
        
        // 查询最近打开的项目列表
        let query = "SELECT value FROM ItemTable WHERE key = 'history.recentlyOpenedPathsList'"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            log("⚠️ SQL 准备失败", level: .warning)
            return []
        }
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            if let valueBlob = sqlite3_column_text(statement, 0) {
                let jsonString = String(cString: valueBlob)
                
                // 解析 JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let entries = json["entries"] as? [[String: Any]] {
                    
                    for entry in entries {
                        // 获取 folderUri 或 fileUri
                        let uri = entry["folderUri"] as? String ?? entry["fileUri"] as? String ?? ""
                        
                        if uri.hasPrefix("file://"), !uri.contains(".") || uri.hasSuffix("/") || !uri.contains(".") {
                            // 去掉 file:// 前缀
                            let path = String(uri.dropFirst(7))
                            let projectName = (path as NSString).lastPathComponent
                            
                            // 检查目录是否存在
                            var isDir: ObjCBool = false
                            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                                let project = IDEProject(
                                    name: projectName,
                                    path: path,
                                    ideName: config.name,
                                    prefix: config.primaryPrefix,
                                    appPath: (config.appPath as NSString).expandingTildeInPath,
                                    urlScheme: config.urlScheme,
                                    appIcon: NSWorkspace.shared.icon(forFile: (config.appPath as NSString).expandingTildeInPath)
                                )
                                projects.append(project)
                            }
                        }
                    }
                }
            }
        }
        
        log("✅ \(config.name) 找到 \(projects.count) 个项目")
        return projects
    }
    
    /// 解析 JetBrains recentProjects.xml（按 projectOpenTimestamp 排序）
    private func parseJetBrainsProjects(config: IDEConfig) -> [IDEProject] {
        let expandedPath = (config.recentProjectsPath as NSString).expandingTildeInPath
        
        log("📂 解析 \(config.name) 最近项目 (JetBrains 格式): \(expandedPath)")
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            log("⚠️ 文件不存在: \(expandedPath)", level: .warning)
            return []
        }
        
        guard let data = FileManager.default.contents(atPath: expandedPath),
              let content = String(data: data, encoding: .utf8) else {
            log("⚠️ 无法读取文件: \(expandedPath)", level: .warning)
            return []
        }
        
        // 临时结构存储项目和时间戳
        struct ProjectWithTimestamp {
            let project: IDEProject
            let timestamp: Int64
        }
        
        var projectsWithTimestamp: [ProjectWithTimestamp] = []
        
        // 解析每个 entry 块
        // 正则匹配 entry 块：<entry key="$USER_HOME$/path">...</entry>
        let entryPattern = #"<entry key="\$USER_HOME\$([^"]+)">([\s\S]*?)</entry>"#
        guard let entryRegex = try? NSRegularExpression(pattern: entryPattern) else {
            log("⚠️ 正则表达式创建失败", level: .warning)
            return []
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = entryRegex.matches(in: content, range: range)
        
        for match in matches {
            guard let pathRange = Range(match.range(at: 1), in: content),
                  let entryContentRange = Range(match.range(at: 2), in: content) else {
                continue
            }
            
            let relativePath = String(content[pathRange])
            let fullPath = NSHomeDirectory() + relativePath
            let entryContent = String(content[entryContentRange])
            
            // 提取 projectOpenTimestamp
            var timestamp: Int64 = 0
            let timestampPattern = #"projectOpenTimestamp"\s+value="(\d+)""#
            if let tsRegex = try? NSRegularExpression(pattern: timestampPattern),
               let tsMatch = tsRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
               let tsRange = Range(tsMatch.range(at: 1), in: entryContent) {
                timestamp = Int64(entryContent[tsRange]) ?? 0
            }
            
            // 提取项目名
            let projectName = (fullPath as NSString).lastPathComponent
            
            // 检查项目目录是否存在
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                let project = IDEProject(
                    name: projectName,
                    path: fullPath,
                    ideName: config.name,
                    prefix: config.primaryPrefix,
                    appPath: (config.appPath as NSString).expandingTildeInPath,
                    urlScheme: config.urlScheme,
                    appIcon: NSWorkspace.shared.icon(forFile: (config.appPath as NSString).expandingTildeInPath)
                )
                projectsWithTimestamp.append(ProjectWithTimestamp(project: project, timestamp: timestamp))
            }
        }
        
        // 按 timestamp 降序排序（最近打开的在前面）
        projectsWithTimestamp.sort { $0.timestamp > $1.timestamp }
        
        let projects = projectsWithTimestamp.map { $0.project }
        log("✅ \(config.name) 找到 \(projects.count) 个项目（已按时间排序）")
        return projects
    }
    
    /// 清除缓存
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.projectCache.removeAll()
            log("🗑 IDE 项目缓存已清除")
        }
    }
    
    // MARK: - 打开项目
    
    /// 用对应 IDE 打开项目
    func openProject(_ project: IDEProject) {
        let urlString = buildURLString(project.urlScheme, project.path)

        if let url = URL(string: urlString) {
            log("🚀 尝试使用 URL Scheme 打开: \(urlString)")
            if NSWorkspace.shared.open(url) {
                return
            }
            log("⚠️ URL Scheme 打开失败", level: .warning)
        } else {
            log("⚠️ URL Scheme 无效: \(urlString)", level: .warning)
        }
    }

    /// 构建 URL 字符串
    private func buildURLString(_ scheme: String, _ path: String) -> String {
        if scheme.hasSuffix("=") {
            // Query 参数形式: goland://open?file=PATH
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
            return scheme + encodedPath
        } else {
            // 路径形式: vscode://file/PATH
            var urlString = scheme
            if !urlString.hasSuffix("/") && !path.hasPrefix("/") {
                urlString += "/"
            }
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            return urlString + encodedPath
        }
    }
}
