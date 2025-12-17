import Foundation
import CoreServices

// MARK: - 词典条目数据结构

struct DictionaryEntry {
    let word: String
    let phonetic: String?
    let shortTranslation: String    // 用于列表展示的简短翻译
    let fullTranslation: String     // 用于详情展示的完整翻译
}

// MARK: - 系统词典服务

class DictionaryService {
    static let shared = DictionaryService()
    
    // 缓存查询结果，避免重复查询
    private var cache: [String: DictionaryEntry?] = [:]
    private let cacheQueue = DispatchQueue(label: "com.spotlight.dictionary.cache")
    
    private init() {
        log("📖 DictionaryService 初始化")
    }
    
    /// 查询单词
    /// - Parameter word: 要查询的英文单词
    /// - Returns: 词典条目，如果查不到返回 nil
    func lookup(word: String) async -> DictionaryEntry? {
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查缓存
        if let cached = cacheQueue.sync(execute: { cache[normalizedWord] }) {
            log("📖 从缓存返回词典结果: \(normalizedWord)")
            return cached
        }
        
        log("📖 查询系统词典: \(normalizedWord)")
        
        // 使用系统词典查询
        guard let definition = lookupSystemDictionary(word: normalizedWord) else {
            log("📖 未找到词典条目: \(normalizedWord)")
            // 缓存空结果，避免重复查询
            cacheQueue.async { [weak self] in
                self?.cache[normalizedWord] = nil
            }
            return nil
        }
        
        // 解析结果
        let entry = parseDefinition(word: normalizedWord, definition: definition)
        
        // 缓存结果
        cacheQueue.async { [weak self] in
            self?.cache[normalizedWord] = entry
        }
        
        log("📖 找到词典条目: \(normalizedWord) -> \(entry.shortTranslation)")
        return entry
    }
    
    /// 判断是否为纯英文单词
    /// - Parameter query: 输入字符串
    /// - Returns: 是否为英文单词
    func isEnglishWord(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 长度检查：至少2个字符
        guard trimmed.count >= 2 else { return false }
        
        // 只包含字母（允许连字符，如 well-known）
        let pattern = "^[A-Za-z]+(-[A-Za-z]+)*$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - 私有方法
    
    /// 调用系统词典 API
    private func lookupSystemDictionary(word: String) -> String? {
        // DCSCopyTextDefinition 是 macOS 系统词典 API
        // 第二个参数是词典引用，nil 表示使用默认词典
        guard let cfDefinition = DCSCopyTextDefinition(
            nil,
            word as CFString,
            CFRangeMake(0, word.count)
        ) else {
            return nil
        }
        
        return cfDefinition.takeRetainedValue() as String
    }
    
    /// 解析词典定义文本
    private func parseDefinition(word: String, definition: String) -> DictionaryEntry {
        // 系统词典返回的是纯文本，没有换行符，我们需要智能插入换行
        
        // 清理 HTML 标记
        var text = definition
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        
        // 提取音标（通常在 | 或 / 之间）
        var phonetic: String?
        // 匹配英式和美式音标，如 "BrE kənˈtent, AmE kənˈtent"
        let phoneticPattern = "\\|\\s*([^|]+)\\s*\\|"
        if let regex = try? NSRegularExpression(pattern: phoneticPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                phonetic = String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // === 智能分段：在关键位置插入换行符 ===
        
        // 1. 在大写字母+句点前换行（A. B. C. D. 等词性标记）
        text = text.replacingOccurrences(
            of: "([^\\n])\\s*([A-Z])\\.\\s*(noun|verb|adjective|adverb|transitive|intransitive|reflexive|uncountable|countable)",
            with: "$1\n\n$2. $3",
            options: .regularExpression
        )
        
        // 2. 在带圆圈序号前换行（①②③④等）
        text = text.replacingOccurrences(
            of: "([^\\n])\\s*([①-⑳])",
            with: "$1\n  $2",
            options: .regularExpression
        )
        
        // 3. 在常见词性词前换行（如果前面没有字母）
        let posPatterns = [
            "transitive verb", "intransitive verb", "reflexive verb",
            "uncountable", "countable", "plural"
        ]
        for pos in posPatterns {
            text = text.replacingOccurrences(
                of: "([^a-zA-Z\\n])\\s*\(" + NSRegularExpression.escapedPattern(for: pos) + ")",
                with: "$1\n\n$2",
                options: .caseInsensitive
            )
        }
        
        // 4. 在中文释义的分号处换行（表示不同释义）
        text = text.replacingOccurrences(of: "; ", with: "\n  • ")
        
        // 5. 垄号内容前加空格美化
        text = text.replacingOccurrences(of: "‹", with: "\n    › ")
        
        // 6. 清理多余空行和空格
        text = text.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 分行处理
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .init(charactersIn: " ")) }
        
        // 提取简短翻译（第一个包含中文的段落）
        let shortTranslation: String
        if let firstChinese = lines.first(where: { line in
            // 检查是否包含中文字符
            line.unicodeScalars.contains { scalar in
                (0x4E00...0x9FFF).contains(scalar.value)
            }
        }) {
            // 截取中文部分
            let trimmed = firstChinese.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 60 {
                let index = trimmed.index(trimmed.startIndex, offsetBy: 57)
                shortTranslation = String(trimmed[..<index]) + "..."
            } else {
                shortTranslation = trimmed
            }
        } else {
            shortTranslation = lines.first ?? "无释义"
        }
        
        // 完整翻译
        let fullTranslation = lines.joined(separator: "\n")
        
        return DictionaryEntry(
            word: word,
            phonetic: phonetic,
            shortTranslation: shortTranslation,
            fullTranslation: fullTranslation.isEmpty ? "无详细释义" : fullTranslation
        )
    }
    
    /// 清除缓存
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.cache.removeAll()
            log("📖 词典缓存已清除")
        }
    }
}
