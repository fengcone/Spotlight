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
            styleMask: [.borderless, .titled, .fullSizeContentView],  // 移除 .nonactivatingPanel
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContentView()
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
        
        // 不显示在任务切换器中
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        
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
        
        // 重新居中 - 使用更精确的居中算法
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = frame
            
            // 将窗口置于屏幕上部 1/4 处
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY + screenRect.height / 4
            
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
        log("✅ 搜索状态已重置")
    }
    
    func performSearch() {
        log("🔍 执行搜索: '\(searchText)'")
        
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
        case .url:
            if let url = URL(string: result.path) {
                NSWorkspace.shared.open(url)
            }
        case .file:
            // 使用新的 API
            let url = URL(filePath: result.path)
            NSWorkspace.shared.open(url)
        }
        
        onDismiss?()
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
            
            // 搜索结果列表
            if !controller.searchResults.isEmpty {
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(controller.searchResults.enumerated()), id: \.offset) { index, result in
                            SearchResultRow(
                                result: result,
                                isSelected: index == controller.selectedIndex
                            )
                            .onTapGesture {
                                controller.selectedIndex = index
                                controller.executeSelected()
                            }
                        }
                    }
                }
                .frame(height: 330)  // 固定高度
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
        .onChange(of: controller.searchText) { _ in
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

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let controller: SearchViewController
    
    func makeNSView(context: Context) -> NSTextField {
        log("📝 创建 SearchTextField...")
        let textField = NSTextField()
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
                log("⎋ Escape 键")
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
