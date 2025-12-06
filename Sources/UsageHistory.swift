import Foundation

/// 使用历史记录管理器
/// 记录用户选择的搜索结果，用于智能排序
class UsageHistory {
    static let shared = UsageHistory()
    
    private let defaults = UserDefaults.standard
    private let maxHistorySize = 1000 // 最多保存1000条记录
    private var usageCount: [String: Int] = [:]  // path -> 使用次数
    private var lastUsedTime: [String: Date] = [:]  // path -> 最后使用时间
    
    private init() {
        loadHistory()
    }
    
    /// 记录一次使用
    func recordUsage(path: String) {
        // 更新使用次数
        usageCount[path, default: 0] += 1
        
        // 更新最后使用时间
        lastUsedTime[path] = Date()
        
        // 保存到持久化存储
        saveHistory()
        
        log("📊 记录使用: \(path), 次数: \(usageCount[path] ?? 0)")
    }
    
    /// 获取使用次数
    func getUsageCount(path: String) -> Int {
        return usageCount[path] ?? 0
    }
    
    /// 获取最后使用时间
    func getLastUsedTime(path: String) -> Date? {
        return lastUsedTime[path]
    }
    
    /// 计算使用权重（综合考虑使用次数和最近性）
    func getUsageWeight(path: String) -> Double {
        let count = Double(usageCount[path] ?? 0)
        
        // 时间衰减因子：最近使用的权重更高
        var timeWeight = 1.0
        if let lastUsed = lastUsedTime[path] {
            let daysSinceLastUse = Date().timeIntervalSince(lastUsed) / 86400.0  // 转换为天数
            // 每天衰减10%，最多衰减到0.1
            timeWeight = max(0.1, 1.0 - daysSinceLastUse * 0.1)
        }
        
        // 综合权重 = 使用次数 * 时间权重
        return count * timeWeight
    }
    
    /// 加载历史记录
    private func loadHistory() {
        if let countData = defaults.data(forKey: "usageCount"),
           let decodedCount = try? JSONDecoder().decode([String: Int].self, from: countData) {
            usageCount = decodedCount
        }
        
        if let timeData = defaults.data(forKey: "lastUsedTime"),
           let decodedTime = try? JSONDecoder().decode([String: Date].self, from: timeData) {
            lastUsedTime = decodedTime
        }
        
        log("📊 加载使用历史: \(usageCount.count) 条记录")
    }
    
    /// 保存历史记录
    private func saveHistory() {
        // 限制历史记录大小
        if usageCount.count > maxHistorySize {
            // 按使用次数排序，保留最常用的
            let sortedPaths = usageCount.sorted { $0.value > $1.value }.prefix(maxHistorySize)
            usageCount = Dictionary(uniqueKeysWithValues: Array(sortedPaths))
            
            // 清理对应的时间记录
            let validPaths = Set(usageCount.keys)
            lastUsedTime = lastUsedTime.filter { validPaths.contains($0.key) }
        }
        
        // 保存到 UserDefaults
        if let countData = try? JSONEncoder().encode(usageCount) {
            defaults.set(countData, forKey: "usageCount")
        }
        
        if let timeData = try? JSONEncoder().encode(lastUsedTime) {
            defaults.set(timeData, forKey: "lastUsedTime")
        }
    }
    
    /// 清除历史记录
    func clearHistory() {
        usageCount.removeAll()
        lastUsedTime.removeAll()
        defaults.removeObject(forKey: "usageCount")
        defaults.removeObject(forKey: "lastUsedTime")
        log("🗑️ 清除使用历史")
    }
}
