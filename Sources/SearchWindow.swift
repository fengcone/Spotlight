import Cocoa
import SwiftUI

class SearchWindow: NSWindow {
    private var searchViewController: SearchViewController?
    private let configManager: ConfigManager
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
        
        // 窗口配置
        let windowRect = NSRect(x: 0, y: 0, width: 600, height: 400)
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContentView()
    }

    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    private func setupWindow() {
        log("🛠 设置窗口属性...")
        
        // 窗口属性
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        
        // 关键：允许窗口成为 Key Window
        isMovableByWindowBackground = true
        
        // 隐藏标题栏但保持功能
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        // 设置为标准窗口（不是面板）以便接收键盘输入
        isReleasedWhenClosed = false
        
        // 关键：禁止 SwiftUI 自动调整窗口大小
        styleMask.insert(.resizable)
        setContentSize(NSSize(width: 600, height: 400))
        minSize = NSSize(width: 600, height: 400)
        maxSize = NSSize(width: 600, height: 500)
        
        log("❓ 窗口 Level: \(level.rawValue)")
        log("❓ 窗口不透明: \(isOpaque)")
        log("❓ 窗口最小大小: \(minSize)")
        
        // 居中显示
        center()
        
        // 不显示在任务切换器中，但支持全屏空间
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        log("✅ 窗口属性设置完成")
    }
    
    private func setupContentView() {
        log("📝 设置窗口内容...")
        searchViewController = SearchViewController(configManager: configManager)
        searchViewController?.onDismiss = { [weak self] in
            self?.hide()
        }
        
        let hostingView = NSHostingView(rootView: searchViewController!.searchView)
        contentView = hostingView
        
        log("✅ 窗口内容设置完成")
        log("❓ ContentView: \(contentView != nil)")
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        log("\n🔍 ========== 显示搜索窗口 ==========")
        
        // 根本修复：使用鼠标位置确定当前屏幕，而不是 NSScreen.main
        // 这样无论用户在哪个屏幕（包括全屏应用），窗口都会显示在正确的屏幕上
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
        
        if let screen = currentScreen {
            let screenRect = screen.visibleFrame
            let windowRect = frame
            
            // 将窗口置于屏幕上部 1/4 处
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY + screenRect.height / 4
            
            log("📍 鼠标位置: (\(mouseLocation.x), \(mouseLocation.y))")
            log("📺 当前屏幕: \(screen.localizedName)")
            log("📍 窗口位置: (\(x), \(y))")
            log("📊 窗口大小: \(windowRect.width) x \(windowRect.height)")
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 显示窗口
        log("👁 makeKeyAndOrderFront...")
        makeKeyAndOrderFront(nil)
        
        // 强制成为 Key Window - 这是关键！
        log("🔑 强制成为 Key Window...")
        makeKey()
        orderFrontRegardless()  // 强制置顶
        
        // 激活应用以获得焦点
        log("⚡ 激活应用...")
        NSApp.activate(ignoringOtherApps: true)
        
        // 再次确认成为 Key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if !self.isKeyWindow {
                log("⚠️ 窗口仍未成为 Key，再次尝试...")
                self.makeKey()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        // 检查窗口状态
        log("❓ 窗口是否可见: \(isVisible)")
        log("❓ 窗口是否是 Key: \(isKeyWindow)")
        log("❓ 窗口是否是 Main: \(isMainWindow)")
        log("❓ 窗口 canBecomeKey: \(canBecomeKey)")
        
        // 重置搜索内容
        log("🔄 重置搜索内容...")
        searchViewController?.resetSearch()
        
        log("✅ 搜索窗口显示完成\n")
    }
    
    func hide() {
        log("🚫 隐藏搜索窗口")
        orderOut(nil)
    }
}

class SearchViewController: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var selectedIndex: Int = 0
    @Published var dictionaryDetail: DictionaryEntry?  // 词典详情
    
    let configManager: ConfigManager
    var onDismiss: (() -> Void)?
    
    private let searchEngine: SearchEngine
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.searchEngine = SearchEngine(configManager: configManager)
    }
    
    var searchView: some View {
        SearchView(controller: self)
    }
    
    func resetSearch() {
        log("🔄 SearchViewController.resetSearch() 被调用")
        searchText = ""
        searchResults = []
        selectedIndex = 0
        dictionaryDetail = nil  // 清除词典详情
        log("✅ 搜索状态已重置")
    }
    
    func performSearch() {
        log("🔍 执行搜索: '\(searchText)'")
        
        // 清除词典详情（开始新搜索时）
        dictionaryDetail = nil
        
        // 如果搜索文本为空，清空结果
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            log("⚠️ 搜索文本为空，清空结果")
            searchResults = []
            selectedIndex = 0
            return
        }
        
        Task {
            let results = await searchEngine.search(query: searchText)
            await MainActor.run {
                log("✅ 搜索完成，找到 \(results.count) 个结果")
                if results.isEmpty {
                    log("⚠️ 没有找到匹配的结果")
                } else {
                    log("📋 结果列表:")
                    for (index, result) in results.prefix(5).enumerated() {
                        log("  \(index + 1). \(result.title) (\(result.type))")
                    }
                }
                self.searchResults = results
                self.selectedIndex = 0
            }
        }
    }
    
    func selectNext() {
        if !searchResults.isEmpty {
            selectedIndex = (selectedIndex + 1) % searchResults.count
        }
    }
    
    func selectPrevious() {
        if !searchResults.isEmpty {
            selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : searchResults.count - 1
        }
    }
    
    func executeSelected() {
        guard selectedIndex < searchResults.count else { return }
        let result = searchResults[selectedIndex]
        
        // 记录使用历史（用于智能排序）
        UsageHistory.shared.recordUsage(path: result.path)
        log("🚀 执行: \(result.title) (\(result.path))")
        
        switch result.type {
        case .application:
            // 使用新的 API
            let url = URL(filePath: result.path)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            onDismiss?()
        case .url:
            if let url = URL(string: result.path) {
                NSWorkspace.shared.open(url)
            }
            onDismiss?()
        case .file:
            // 使用新的 API
            let url = URL(filePath: result.path)
            NSWorkspace.shared.open(url)
            onDismiss?()
        case .dictionary:
            // 词典结果：显示详情，不关闭窗口
            Task {
                let word = result.title
                if let entry = await DictionaryService.shared.lookup(word: word) {
                    await MainActor.run {
                        self.dictionaryDetail = entry
                        log("📖 显示词典详情: \(word)")
                    }
                }
            }
        case .ideProject:
            // IDE 项目：解析路径并打开
            // path 格式: ide://prefix/项目路径
            if result.path.hasPrefix("ide://") {
                let pathWithoutScheme = String(result.path.dropFirst(6))  // 去掉 "ide://"
                if let firstSlash = pathWithoutScheme.firstIndex(of: "/") {
                    let prefix = String(pathWithoutScheme[..<firstSlash])
                    let projectPath = String(pathWithoutScheme[pathWithoutScheme.index(after: firstSlash)...])
                    
                    // 获取对应 IDE 的 URL Scheme
                    if let ideMatch = IDEProjectService.shared.parseIDEPrefix(query: prefix) {
                        let project = IDEProject(
                            name: "",
                            path: projectPath,
                            ideName: ideMatch.config.name,
                            prefix: ideMatch.config.primaryPrefix,
                            appPath: (ideMatch.config.appPath as NSString).expandingTildeInPath,
                            urlScheme: ideMatch.config.urlScheme,
                            appIcon: NSWorkspace.shared.icon(forFile: (ideMatch.config.appPath as NSString).expandingTildeInPath)
                        )
                        IDEProjectService.shared.openProject(project)
                    }
                }
            }
            onDismiss?()
        case .dingTalk:
            // 钉钉搜索：运行 AppleScript
            let keyword = result.path
            runDingTalkSearchScript(keyword: keyword)
            onDismiss?()
        case .chromeTab:
            // Chrome 标签页：激活已打开的标签
            if result.path.hasPrefix("chromeTab://") {
                let tabId = String(result.path.dropFirst(12))  // 去掉 "chromeTab://" (长度12)
                if let tab = ChromeTabsService.shared.getTab(byId: tabId) {
                    ChromeTabsService.shared.activateTab(tab)
                    onDismiss?()
                } else {
                    log("⚠️ 未找到标签页: \(tabId)", level: .warning)
                    // 标签页可能已关闭，刷新缓存
                    ChromeTabsService.shared.refreshTabs()
                }
            }
        }
    }
    
    private func runDingTalkSearchScript(keyword: String) {
        log("🤖 尝试钉钉搜索自动化: \(keyword)")
        
        // 0. 备份剪贴板原有内容
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
        
        // 1. 将关键词存入剪贴板
        pasteboard.clearContents()
        pasteboard.setString(keyword, forType: .string)

        // 2. 唤起钉钉
        if let dingApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.alibaba.DingTalkMac" || $0.localizedName?.contains("DingTalk") == true }) {
            dingApp.activate()
        } else {
            // 如果没运行，尝试通过 URL 唤起
            if let url = URL(string: "dingtalk://") {
                NSWorkspace.shared.open(url)
            }
        }

        // 3. 延迟执行模拟按键（等待窗口获得焦点）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // 检查权限
            if !AXIsProcessTrusted() {
                log("❌ 缺少辅助功能权限！请在系统设置中授予 Spotlight 辅助功能权限。", level: .error)
                // 恢复剪贴板
                self.restorePasteboard(originalItems: originalItems)
                return
            }
            
            log("⌨️ 1. 发送 Cmd+F")
            self.simulateCommandKey(key: 0x03) // F
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                log("⌨️ 2. 发送 Cmd+V (粘贴内容)")
                self.simulateCommandKey(key: 0x09) // V
                
                // 关键点：给钉钉更长的时间去模糊匹配联系人列表
                log("⏳ 等待钉钉搜索响应...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    log("⌨️ 3. 发送 Enter (确认搜索结果)")
                    self.simulateReturnKey()
                    log("✅ 自动化序列执行完毕")
                    
                    // 4. 恢复剪贴板原有内容
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.restorePasteboard(originalItems: originalItems)
                        log("📋 剪贴板已恢复")
                    }
                }
            }
        }
    }
    
    // 恢复剪贴板内容
    private func restorePasteboard(originalItems: [NSPasteboardItem]?) {
        guard let items = originalItems, !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    // 模拟 Command + Key
    private func simulateCommandKey(key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // 模拟回车
    private func simulateReturnKey() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) // Return key code 36
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    
    func dismiss() {
        onDismiss?()
    }
}

struct SearchView: View {
    @ObservedObject var controller: SearchViewController
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索输入框
            SearchTextField(text: $controller.searchText, controller: controller)
                .frame(height: 60)  // 固定高度
                .padding(.horizontal)
            
            // 词典详情区域
            if let detail = controller.dictionaryDetail {
                Divider()
                DictionaryDetailView(entry: detail, onClose: {
                    controller.dictionaryDetail = nil
                })
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            // 搜索结果列表
            else if !controller.searchResults.isEmpty {
                Divider()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(controller.searchResults.enumerated()), id: \.offset) { index, result in
                                SearchResultRow(
                                    result: result,
                                    isSelected: index == controller.selectedIndex
                                )
                                .id(index)  // 为每个行添加唯一ID
                                .onTapGesture {
                                    controller.selectedIndex = index
                                    controller.executeSelected()
                                }
                            }
                        }
                    }
                    .frame(height: 330)  // 固定高度
                    // 当选中项变化时，自动滚动到可见区域
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else {
                // 没有结果时显示占位空间，保持窗口大小
                Spacer()
                    .frame(height: 330)
            }
        }
        .frame(width: 600, height: 400)  // 固定总高度
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onChange(of: controller.searchText) {
            // 取消之前的搜索任务
            searchTask?.cancel()
            
            // 防抖：延迟 150ms 执行搜索
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms
                if !Task.isCancelled {
                    await MainActor.run {
                        controller.performSearch()
                    }
                }
            }
        }
    }
}

// MARK: - 自定义 NSTextField，支持 Command+V/A/X/C 快捷键

class EditableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 检查是否是 Command 键组合
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        switch key {
        case "v":  // Command+V 粘贴
            if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                return true
            }
        case "c":  // Command+C 复制
            if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                return true
            }
        case "x":  // Command+X 剪切
            if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                return true
            }
        case "a":  // Command+A 全选
            if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                return true
            }
        case "z":  // Command+Z 撤销
            if event.modifierFlags.contains(.shift) {
                // Command+Shift+Z 重做
                if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) {
                    return true
                }
            } else {
                if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) {
                    return true
                }
            }
        default:
            break
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let controller: SearchViewController
    
    func makeNSView(context: Context) -> NSTextField {
        log("📝 创建 SearchTextField...")
        let textField = EditableTextField()  // 使用自定义的 TextField
        textField.placeholderString = "搜索应用、网址..."
        textField.font = .systemFont(ofSize: 24)
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator
        
        // 关键：禁止自动选中文本
        textField.lineBreakMode = .byTruncatingTail
        textField.usesSingleLineMode = true
        
        log("✅ TextField 创建完成")
        log("❓ TextField 可编辑: \(textField.isEditable)")
        log("❓ TextField 可选择: \(textField.isSelectable)")
        log("❓ TextField 启用: \(textField.isEnabled)")
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // 关键修复：只在文本真正不同时才更新，避免覆盖用户正在输入的内容
        if nsView.stringValue != text {
            log("🔄 updateNSView - 更新文本: '\(nsView.stringValue)' -> '\(text)'")
            nsView.stringValue = text
        }
        
        // 只在初次显示时设置焦点（通过 coordinator 的标志位控制）
        if !context.coordinator.hasSetInitialFocus, let window = nsView.window {
            context.coordinator.hasSetInitialFocus = true
            DispatchQueue.main.async {
                log("🎯 初次设置 TextField 为 FirstResponder...")
                window.makeFirstResponder(nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, controller: controller)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let controller: SearchViewController
        var hasSetInitialFocus = false  // 标志位：是否已设置初次焦点
        
        init(text: Binding<String>, controller: SearchViewController) {
            _text = text
            self.controller = controller
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                log("⌨️ 文本变化: '\(textField.stringValue)'")
                // 直接更新，不会触发 updateNSView 因为值相同
                text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            log("🎮 接收到命令: \(commandSelector)")
            
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                log("⬇️ 下键")
                controller.selectNext()
                return true
            case #selector(NSResponder.moveUp(_:)):
                log("⬆️ 上键")
                controller.selectPrevious()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                log("⏎ Enter 键")
                controller.executeSelected()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                log("⏋ Escape 键")
                // 如果正在显示词典详情，关闭详情
                if controller.dictionaryDetail != nil {
                    controller.dictionaryDetail = nil
                    return true
                }
                // 否则关闭窗口
                controller.dismiss()
                return true
            default:
                log("❓ 未处理的命令: \(commandSelector)")
                return false
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(nsImage: result.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}

// MARK: - 词典详情视图

struct DictionaryDetailView: View {
    let entry: DictionaryEntry
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(.blue)
                    Text(entry.word)
                        .font(.system(size: 20, weight: .bold))
                    if let phonetic = entry.phonetic {
                        Text("/\(phonetic)/")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("关闭词典详情")
            }
            
            Divider()
            
            // 详细释义
            ScrollView {
                Text(entry.fullTranslation)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(4)  // 增加行间距
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: 250)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
