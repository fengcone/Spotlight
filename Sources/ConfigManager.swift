import Foundation
import Carbon

// 快捷键动作类型
enum HotKeyAction {
    case toggleSearch
    case openApp(String)
}

// 配置管理器
class ConfigManager: ObservableObject {
    @Published var mainHotKey: HotKeyConfig
    @Published var appHotKeys: [String: HotKeyConfig] = [:]
    @Published var browserHistoryEnabled: Bool = true
    
    private let defaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        
        // 默认主快捷键: Command + Space
        mainHotKey = HotKeyConfig(
            key: "space",
            modifiers: [.command]
        )
        
        // 加载保存的配置
        loadConfig()
    }
    
    func loadConfig() {
        if let data = defaults.data(forKey: "mainHotKey"),
           let decoded = try? JSONDecoder().decode(HotKeyConfig.self, from: data) {
            mainHotKey = decoded
        }
        
        if let data = defaults.data(forKey: "appHotKeys"),
           let decoded = try? JSONDecoder().decode([String: HotKeyConfig].self, from: data) {
            appHotKeys = decoded
        }
        
        // 修复: 如果 key 不存在，使用默认值 true
        if defaults.object(forKey: "browserHistoryEnabled") != nil {
            browserHistoryEnabled = defaults.bool(forKey: "browserHistoryEnabled")
        } else {
            // 首次运行，默认启用
            browserHistoryEnabled = true
            defaults.set(true, forKey: "browserHistoryEnabled")
        }
    }
    
    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(mainHotKey) {
            defaults.set(encoded, forKey: "mainHotKey")
        }
        
        if let encoded = try? JSONEncoder().encode(appHotKeys) {
            defaults.set(encoded, forKey: "appHotKeys")
        }
        
        defaults.set(browserHistoryEnabled, forKey: "browserHistoryEnabled")
    }
    
    // 添加应用快捷键映射
    func addAppHotKey(appName: String, hotKey: HotKeyConfig) {
        appHotKeys[appName] = hotKey
        saveConfig()
    }
    
    // 获取预设的应用配置
    func getDefaultAppMappings() -> [String: String] {
        return [
            "com.google.Chrome": "Chrome",
            "com.googlecode.iterm2": "iTerm2",
            "com.apple.Safari": "Safari",
            "com.microsoft.VSCode": "VSCode",
            "com.apple.finder": "Finder"
        ]
    }
}

// 快捷键配置
struct HotKeyConfig: Codable {
    let key: String
    let modifiers: [KeyModifier]
    
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        for modifier in modifiers {
            result |= modifier.carbonValue
        }
        return result
    }
}

// 键盘修饰符
enum KeyModifier: String, Codable {
    case command
    case option
    case control
    case shift
    
    var carbonValue: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        case .shift: return UInt32(shiftKey)
        }
    }
}
