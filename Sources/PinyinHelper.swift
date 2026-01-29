import Foundation

/// 拼音辅助工具
/// 使用 Core Foundation 的 CFStringTransform 进行中文到拼音的转换
class PinyinHelper {
    static let shared = PinyinHelper()
    
    // 缓存：避免重复转换
    private var cache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.spotlight.pinyin.cache")
    
    private init() {}
    
    /// 将中文字符串转换为拼音（不带声调）
    /// 例如："你好世界" -> "nihaoshijie"
    func toPinyin(_ text: String) -> String {
        // 检查缓存
        var cached: String?
        cacheQueue.sync {
            cached = cache[text]
        }
        if let cached = cached {
            return cached
        }
        
        // 转换
        let mutableString = NSMutableString(string: text)
        
        // 转换为带声调的拼音
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        
        // 去除声调
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        // 转小写并移除空格
        let result = (mutableString as String).lowercased().replacingOccurrences(of: " ", with: "")
        
        // 存入缓存
        cacheQueue.sync {
            cache[text] = result
        }
        
        return result
    }
    
    /// 获取拼音首字母
    /// 例如："你好世界" -> "nhsj"
    func toPinyinInitials(_ text: String) -> String {
        let mutableString = NSMutableString(string: text)
        
        // 转换为带声调的拼音
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        
        // 去除声调
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        // 按空格分割，取每个词的首字母
        let words = (mutableString as String).lowercased().split(separator: " ")
        return words.compactMap { $0.first.map { String($0) } }.joined()
    }
    
    /// 检查 query 是否匹配 target（支持拼音）
    /// 匹配规则：
    /// 1. 原文包含匹配
    /// 2. 全拼匹配
    /// 3. 拼音首字母匹配
    func matches(query: String, target: String) -> Bool {
        let lowerQuery = query.lowercased()
        let lowerTarget = target.lowercased()
        
        // 1. 原文包含匹配
        if lowerTarget.contains(lowerQuery) {
            return true
        }
        
        // 2. 全拼匹配
        let targetPinyin = toPinyin(target)
        if targetPinyin.contains(lowerQuery) {
            return true
        }
        
        // 3. 拼音首字母匹配（只对短查询词有效，避免误匹配）
        if lowerQuery.count <= 6 {
            let targetInitials = toPinyinInitials(target)
            if targetInitials.contains(lowerQuery) {
                return true
            }
        }
        
        return false
    }
}
