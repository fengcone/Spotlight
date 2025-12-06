import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var searchWindow: SearchWindow?
    var globalHotKeyMonitor: GlobalHotKeyMonitor?
    var configManager: ConfigManager!
    var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动日志系统
        log("🚀 Spotlight 启动...")
        
        // 设置应用为辅助应用 (不在 Dock 显示)
        NSApp.setActivationPolicy(.accessory)
        
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
        // 初始化配置管理器
        configManager = ConfigManager()
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 初始化搜索窗口
        searchWindow = SearchWindow(configManager: configManager)
        
        // 设置全局快捷键监听
        setupGlobalHotKey()
        
        log("✅ Spotlight 启动完成")
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Spotlight")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func setupGlobalHotKey() {
        log("⌨️ 设置全局快捷键监听...")
        globalHotKeyMonitor = GlobalHotKeyMonitor(configManager: configManager) { [weak self] action in
            log("🔔 收到快捷键动作: \(action)")
            switch action {
            case .toggleSearch:
                log("🔍 切换搜索窗口")
                self?.toggleSearchWindow()
            case .openApp(let appName):
                log("🚀 打开应用: \(appName)")
                self?.openApplication(appName)
            }
        }
        globalHotKeyMonitor?.start()
        log("✅ 快捷键监听启动完成")
    }
    
    func toggleSearchWindow() {
        log("🔄 toggleSearchWindow() 被调用")
        searchWindow?.toggle()
    }
    
    func openApplication(_ appName: String) {
        let workspace = NSWorkspace.shared
        
        // 尝试通过 bundle identifier 打开
        if let url = workspace.urlForApplication(withBundleIdentifier: appName) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        
        // 尝试通过应用名称打开
        if let url = workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/")) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(configManager: configManager)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        log("🛑 Spotlight 正在退出...")
        Logger.shared.close()
        NSApplication.shared.terminate(nil)
    }
    
    // 检查辅助功能权限
    func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPermissionAlert()
            }
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "Spotlight 需要辅助功能权限来监听全局快捷键。\n\n请在系统设置中授予权限：\n系统设置 → 隐私与安全性 → 辅助功能"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
