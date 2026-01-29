# Chrome 已打开标签页搜索功能设计

## 需求概述

在 Spotlight 中搜索时，优先匹配 Chrome 浏览器中已经打开的标签页。选中后直接激活该标签页，而不是打开新的标签页。

## 功能要求

1. **最高优先级**：已打开的标签页排在所有搜索结果最前面
2. **直接激活**：选中时激活已存在的标签页，不打开新标签
3. **URL + 标题匹配**：搜索关键词同时匹配 URL 和页面标题
4. **定时刷新**：后台每 10 秒获取一次标签页列表

## 架构设计

### 核心组件

新增 `ChromeTabsService` 服务：

```
ChromeTabsService
├── AppleScript 执行器    # 与 Chrome 通信
├── 标签页缓存              # 存储当前打开的标签
├── 定时刷新器              # 每 10 秒更新
└── 激活控制器              # 切换到指定标签
```

### 数据结构

```swift
struct ChromeTab {
    let id: String              // 唯一标识: "windowIndex-tabIndex"
    let url: String             // 完整 URL
    let title: String           // 页面标题
    let windowIndex: Int        // 窗口索引（1-based）
    let tabIndex: Int           // 标签页索引（1-based）
}
```

### AppleScript 交互

**获取标签页**（每 10 秒）：
```applescript
tell application "Google Chrome"
    repeat with w in every window
        repeat with t in every tab in w
            get {URL, title} of t
        end repeat
    end repeat
end tell
```

**激活标签页**（用户选择时）：
```applescript
tell application "Google Chrome"
    activate
    tell window {windowIndex}
        set active tab index to {tabIndex}
    end tell
    set index of window {windowIndex} to 1
end tell
```

## 搜索优先级调整

```
1. 应用程序 (最高)
2. IDE 项目 (最高)
3. 钉钉搜索 (最高)
4. Chrome 已打开标签 (最高) ← 新增
5. 词典翻译 (中)
6. Chrome 书签 (中)
7. Chrome 历史 (低)
```

## UI 显示

已打开标签页使用特殊图标标识：
```
🔓 GitHub - Issues
```

## 边界情况处理

| 场景 | 处理策略 |
|------|----------|
| Chrome 未运行 | 返回空结果 |
| 无头模式 | AppleScript 自动跳过 |
| 隐私/无痕窗口 | 正常获取 |
| 很多标签页 (100+) | 设置上限 200 个 |
| 重复 URL | 都保留 |

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| Chrome 未运行 | 不显示已打开标签 |
| 标签页已关闭 | 从缓存移除，下次刷新自动修正 |
| AppleScript 失败 | 记录日志，下次刷新时重试 |
| 索引越界 | 重新获取标签页列表 |

## 文件结构

```
Sources/
├── ChromeTabsService.swift    # 新增
├── SearchEngine.swift          # 修改：集成标签搜索
├── SearchWindow.swift          # 修改：添加图标显示
└── SearchResult.swift          # 修改：新增 .chromeTab 类型
```

## 权限需求

无需额外权限——AppleScript 控制 Chrome 属于标准系统功能。
