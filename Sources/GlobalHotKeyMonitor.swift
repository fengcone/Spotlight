import Cocoa
import Carbon

class GlobalHotKeyMonitor {
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let configManager: ConfigManager
    private let onAction: (HotKeyAction) -> Void
    
    // 热键 ID
    private var hotKeyID = EventHotKeyID(signature: OSType(0x53504F54), id: 1) // 'SPOT'
    
    init(configManager: ConfigManager, onAction: @escaping (HotKeyAction) -> Void) {
        self.configManager = configManager
        self.onAction = onAction
    }
    
    func start() {
        // 注册全局热键事件处理器
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let monitor = Unmanaged<GlobalHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                            nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            // 触发主搜索窗口
            if hotKeyID.id == 1 {
                monitor.onAction(.toggleSearch)
            }
            
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        // 注册主快捷键
        registerMainHotKey()
        
        // 注册本地事件监听器（用于应用快捷键）
        setupLocalEventMonitor()
    }
    
    func stop() {
        if let ref = eventHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    private func registerMainHotKey() {
        let keyCode = keyCodeForString(configManager.mainHotKey.key)
        let modifiers = configManager.mainHotKey.carbonModifiers
        
        RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID,
                          GetApplicationEventTarget(), 0, &eventHotKeyRef)
    }
    
    private func setupLocalEventMonitor() {
        // 监听本地按键事件（当搜索窗口处于活动状态时）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // 检查是否匹配应用快捷键
            for (appBundleID, hotKeyConfig) in self.configManager.appHotKeys {
                if self.matchesHotKey(event: event, config: hotKeyConfig) {
                    self.onAction(.openApp(appBundleID))
                    return nil // 阻止事件传播
                }
            }
            
            return event
        }
    }
    
    private func matchesHotKey(event: NSEvent, config: HotKeyConfig) -> Bool {
        // 检查修饰键
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        var expectedModifiers: NSEvent.ModifierFlags = []
        for modifier in config.modifiers {
            switch modifier {
            case .command: expectedModifiers.insert(.command)
            case .option: expectedModifiers.insert(.option)
            case .control: expectedModifiers.insert(.control)
            case .shift: expectedModifiers.insert(.shift)
            }
        }
        
        // 检查按键
        let keyCode = event.keyCode
        let expectedKeyCode = keyCodeForString(config.key)
        
        return modifierFlags == expectedModifiers && Int(keyCode) == expectedKeyCode
    }
    
    private func keyCodeForString(_ key: String) -> Int {
        let keyMap: [String: Int] = [
            "space": 49,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
            "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
            "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
            "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            "return": 36, "escape": 53, "delete": 51, "tab": 48,
            "left": 123, "right": 124, "down": 125, "up": 126
        ]
        
        return keyMap[key.lowercased()] ?? 49
    }
    
    deinit {
        stop()
    }
}
