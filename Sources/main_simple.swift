import Cocoa
import Carbon

print("Spotlight Lite - Starting...")

// 简单的配置
struct SimpleConfig {
    static var mainHotKey = (keyCode: 49, modifiers: UInt32(cmdKey))  // Command + Space
}

// 全局热键管理器
class SimpleHotKeyManager {
    var eventHotKeyRef: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    
    func start() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
            print("🔍 Hotkey pressed! (Command+Space)")
            print("Opening applications search...")
            
            // 简单演示：打开 Spotlight 搜索
            NSWorkspace.shared.launchApplication(
                withBundleIdentifier: "com.apple.Spotlight",
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
            
            return noErr
        }, 1, &eventSpec, nil, &eventHandler)
        
        var hotKeyID = EventHotKeyID(signature: OSType(0x53504F54), id: 1)
        RegisterEventHotKey(UInt32(SimpleConfig.mainHotKey.keyCode),
                          SimpleConfig.mainHotKey.modifiers,
                          hotKeyID,
                          GetApplicationEventTarget(),
                          0,
                          &eventHotKeyRef)
        
        print("✅ Global hotkey registered: Command+Space")
        print("Press Command+Space to test...")
    }
    
    deinit {
        if let ref = eventHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

// 应用代理
class SimpleAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyManager = SimpleHotKeyManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Spotlight")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Spotlight Lite is running", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        // 启动热键监听
        hotKeyManager.start()
        
        print("🚀 Spotlight Lite is running!")
        print("📍 Check menu bar for icon")
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// 启动应用
let app = NSApplication.shared
let delegate = SimpleAppDelegate()
app.delegate = delegate
app.run()
