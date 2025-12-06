import Foundation

/// 日志管理器
class Logger {
    static let shared = Logger()
    
    private let logDirectory: URL
    private let logFileName: String
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
    private let isPackaged: Bool
    
    private init() {
        // 检测是否为打包应用
        let bundlePath = Bundle.main.bundlePath
        isPackaged = bundlePath.hasSuffix(".app")
        
        // 设置日志目录
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logDirectory = homeDirectory.appendingPathComponent("Library/Logs/Spotlight")
        
        // 设置日志文件名（按日期）
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd"
        let today = dateFormat.string(from: Date())
        logFileName = "spotlight-\(today).log"
        
        // 设置时间戳格式
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // 只有打包应用才创建日志文件
        if isPackaged {
            setupLogFile()
        }
    }
    
    private func setupLogFile() {
        do {
            // 创建日志目录
            if !FileManager.default.fileExists(atPath: logDirectory.path) {
                try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            }
            
            // 创建或打开日志文件
            let logFileURL = logDirectory.appendingPathComponent(logFileName)
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
                let header = "=== Spotlight Log Started at \(dateFormatter.string(from: Date())) ===\n\n"
                try header.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
            // 打开文件句柄用于追加
            fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle?.seekToEndOfFile()
            
        } catch {
            // 如果日志系统失败，静默处理，不影响应用运行
            print("⚠️ 无法初始化日志系统: \(error)")
        }
    }
    
    /// 写入日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // 始终输出到控制台
        print(message)
        
        // 如果是打包应用，同时写入文件
        if isPackaged, let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    /// 关闭日志
    func close() {
        if isPackaged {
            let timestamp = dateFormatter.string(from: Date())
            let footer = "\n=== Spotlight Log Ended at \(timestamp) ===\n\n"
            if let data = footer.data(using: .utf8) {
                fileHandle?.write(data)
            }
            try? fileHandle?.close()
        }
    }
    
    deinit {
        close()
    }
}

/// 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// 全局日志函数
func log(_ message: String, level: LogLevel = .info) {
    Logger.shared.log(message, level: level)
}
