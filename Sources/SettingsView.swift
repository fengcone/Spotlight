import SwiftUI
import Cocoa

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(configManager: configManager)
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
                .tag(0)
            
            ShortcutsSettingsView(configManager: configManager)
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
                .tag(1)
            
            ApplicationsSettingsView(configManager: configManager)
                .tabItem {
                    Label("应用程序", systemImage: "app.badge")
                }
                .tag(2)
        }
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    
    var body: some View {
        Form {
            Section(header: Text("浏览器历史")) {
                Toggle("启用浏览器历史记录搜索", isOn: $configManager.browserHistoryEnabled)
                    .onChange(of: configManager.browserHistoryEnabled) { _ in
                        configManager.saveConfig()
                    }
                
                Text("启用后，可以通过关键词搜索 Chrome 和 Safari 的浏览历史")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("关于")) {
                HStack {
                    Text("版本:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct ShortcutsSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var isRecording = false
    @State private var newHotKey: HotKeyConfig?
    
    var body: some View {
        Form {
            Section(header: Text("主快捷键")) {
                HStack {
                    Text("呼出搜索窗口:")
                    Spacer()
                    
                    Button(action: {
                        isRecording = true
                    }) {
                        Text(formatHotKey(configManager.mainHotKey))
                            .frame(minWidth: 120)
                    }
                    .help("点击录制新快捷键")
                }
                
                Text("按下快捷键组合来设置全局搜索快捷键")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $isRecording) {
            HotKeyRecorderView(
                onRecord: { hotKey in
                    configManager.mainHotKey = hotKey
                    configManager.saveConfig()
                    isRecording = false
                },
                onCancel: {
                    isRecording = false
                }
            )
        }
    }
    
    private func formatHotKey(_ hotKey: HotKeyConfig) -> String {
        var parts: [String] = []
        
        for modifier in hotKey.modifiers {
            switch modifier {
            case .command: parts.append("⌘")
            case .option: parts.append("⌥")
            case .control: parts.append("⌃")
            case .shift: parts.append("⇧")
            }
        }
        
        parts.append(hotKey.key.uppercased())
        
        return parts.joined(separator: " + ")
    }
}

struct ApplicationsSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var applications: [(bundleID: String, name: String)] = []
    
    var body: some View {
        VStack {
            Text("应用快捷键")
                .font(.headline)
                .padding(.top)
            
            Text("为常用应用设置专属快捷键，在搜索窗口激活时可快速打开")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            List {
                ForEach(applications, id: \.bundleID) { app in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: getAppPath(for: app.bundleID) ?? ""))
                            .resizable()
                            .frame(width: 24, height: 24)
                        
                        Text(app.name)
                        
                        Spacer()
                        
                        if let hotKey = configManager.appHotKeys[app.bundleID] {
                            Text(formatHotKey(hotKey))
                                .foregroundColor(.secondary)
                        } else {
                            Text("未设置")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("设置") {
                            // TODO: 打开快捷键录制器
                        }
                    }
                }
            }
        }
        .onAppear {
            loadApplications()
        }
    }
    
    private func loadApplications() {
        let defaultApps = configManager.getDefaultAppMappings()
        applications = defaultApps.map { (bundleID: $0.key, name: $0.value) }
    }
    
    private func getAppPath(for bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    }
    
    private func formatHotKey(_ hotKey: HotKeyConfig) -> String {
        var parts: [String] = []
        
        for modifier in hotKey.modifiers {
            switch modifier {
            case .command: parts.append("⌘")
            case .option: parts.append("⌥")
            case .control: parts.append("⌃")
            case .shift: parts.append("⇧")
            }
        }
        
        parts.append(hotKey.key.uppercased())
        
        return parts.joined(separator: "")
    }
}

struct HotKeyRecorderView: View {
    let onRecord: (HotKeyConfig) -> Void
    let onCancel: () -> Void
    
    @State private var pressedKeys: Set<UInt16> = []
    @State private var modifiers: NSEvent.ModifierFlags = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("按下新的快捷键组合")
                .font(.headline)
            
            Text(getCurrentCombo())
                .font(.title)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            HStack {
                Button("取消") {
                    onCancel()
                }
                
                Button("确定") {
                    if let hotKey = createHotKey() {
                        onRecord(hotKey)
                    }
                }
                .disabled(pressedKeys.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
        .background(KeyEventView(onKeyEvent: handleKeyEvent))
    }
    
    private func getCurrentCombo() -> String {
        guard !pressedKeys.isEmpty else {
            return "等待输入..."
        }
        
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        
        if let keyCode = pressedKeys.first {
            parts.append(keyNameForCode(Int(keyCode)))
        }
        
        return parts.joined(separator: " + ")
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        pressedKeys.insert(event.keyCode)
        modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }
    
    private func createHotKey() -> HotKeyConfig? {
        guard let keyCode = pressedKeys.first else { return nil }
        
        var mods: [KeyModifier] = []
        if modifiers.contains(.command) { mods.append(.command) }
        if modifiers.contains(.option) { mods.append(.option) }
        if modifiers.contains(.control) { mods.append(.control) }
        if modifiers.contains(.shift) { mods.append(.shift) }
        
        let keyName = keyNameForCode(Int(keyCode)).lowercased()
        
        return HotKeyConfig(key: keyName, modifiers: mods)
    }
    
    private func keyNameForCode(_ code: Int) -> String {
        let keyNames: [Int: String] = [
            49: "Space",
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
            34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O",
            35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V",
            13: "W", 7: "X", 16: "Y", 6: "Z"
        ]
        
        return keyNames[code] ?? "Unknown"
    }
}

struct KeyEventView: NSViewRepresentable {
    let onKeyEvent: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyEvent = onKeyEvent
        
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyCaptureView: NSView {
    var onKeyEvent: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }
}

class SettingsWindowController: NSWindowController {
    convenience init(configManager: ConfigManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "设置"
        window.center()
        
        let contentView = SettingsView(configManager: configManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.init(window: window)
    }
}
