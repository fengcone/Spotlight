# 搜索数据源和优先级

## 📚 三个数据源

### 1. 应用程序列表（Application List）
**优先级**: 🥇 最高（+1000 分）

**数据来源**:
- `/Applications` - 系统应用
- `/System/Applications` - 系统内置应用
- `~/Applications` - 用户应用

**搜索字段**:
- 应用名称（CFBundleName）

**示例**:
- Safari
- Google Chrome
- Visual Studio Code
- iTerm

---

### 2. Chrome 书签（Bookmarks）
**优先级**: 🥈 中等（+500 分）

**数据来源**:
- `~/Library/Application Support/Google/Chrome/Default/Bookmarks`

**数据格式**: JSON 文件

**搜索字段**:
- 书签标题（name）
- 书签 URL（url）

**示例**:
- GitHub - https://github.com
- Google - https://google.com
- 语雀文档 - https://yuque.com/xxx

**特点**:
- 手动收藏的网址
- 精选内容，质量高
- 通常是常用网站

---

### 3. 浏览历史（Browser History）
**优先级**: 🥉 最低（+0 分）

**数据来源**:
- `~/Library/Application Support/Google/Chrome/Default/History`

**数据格式**: SQLite 数据库

**搜索字段**:
- 页面标题（title）
- 页面 URL（url）

**排序依据**:
- 访问次数（visit_count）
- 最后访问时间（last_visit_time）

**限制**: 最多加载 500 条最常访问的记录

**示例**:
- 首页 - ASI Console
- 工作台 · 阿里语雀
- GitHub Issues

---

## 🎯 搜索排序逻辑

### 优先级权重

```
应用程序:   基础分数 + 1000
书签:       基础分数 + 500
浏览历史:   基础分数 + 0
```

### 基础分数计算

**模糊匹配分数**:
1. **精确匹配**: 100 分（完全一致）
2. **前缀匹配**: 90 分（以关键词开头）
3. **包含匹配**: 80 分（包含关键词）
4. **字符匹配**: 最高 70 分（首字母缩写等）

**浏览历史额外加成**:
```
最终分数 = 基础匹配分数 × (1 + log10(访问次数 + 1))
```

访问次数越多，分数越高。

---

## 📊 搜索示例

### 示例 1: 搜索 "chrome"

**结果排序**:
1. **Google Chrome** (应用) - 分数: 1090
   - 基础: 90（前缀匹配）
   - 权重: +1000
   
2. **Chrome 扩展商店** (书签) - 分数: 580
   - 基础: 80（包含匹配）
   - 权重: +500
   
3. **Chrome 设置页面** (历史) - 分数: 80
   - 基础: 80（包含匹配）
   - 权重: 0
   - 访问加成: 1.0

---

### 示例 2: 搜索 "github"

**结果排序**:
1. **GitHub Desktop** (应用) - 分数: 1100
   - 基础: 100（精确匹配）
   - 权重: +1000

2. **GitHub** (书签) - 分数: 600
   - 基础: 100（精确匹配）
   - 权重: +500

3. **GitHub Issues** (历史) - 分数: ~120
   - 基础: 90（前缀匹配）
   - 权重: 0
   - 访问加成: 1.3（假设访问 20 次）

---

### 示例 3: 搜索 "语雀"

**结果排序**:
1. **我的文档 - 语雀** (书签) - 分数: 580
   - 基础: 80（包含匹配）
   - 权重: +500

2. **工作台 · 阿里语雀** (历史) - 分数: ~160
   - 基础: 80（包含匹配）
   - 权重: 0
   - 访问加成: 2.0（假设访问 100 次）

---

## 🔍 数据加载流程

### 启动时加载

```
SearchEngine 初始化
    ↓
1. loadApplications()
   - 扫描应用目录
   - 读取 Info.plist
   - 提取应用图标
    ↓
2. loadBookmarks()
   - 读取 Chrome Bookmarks JSON
   - 递归提取所有书签
   - 解析 name 和 url
    ↓
3. loadBrowserHistory()
   - 复制 Chrome History 数据库
   - 查询访问次数最多的 500 条
   - 按访问次数排序
    ↓
✅ 加载完成
```

### 预期日志

```
🛠 设置窗口属性...
✅ 窗口属性设置完成
📝 设置窗口内容...

🔖 开始加载 Chrome 书签...
✅ 书签加载完成，共 150 条记录

📚 开始加载浏览器历史...
✅ 浏览器历史加载完成，共 500 条记录

✅ 窗口内容设置完成
```

---

## 🎨 UI 显示效果

### 搜索 "google" 的预期结果

```
┌────────────────────────────────────────┐
│  [google]                              │
├────────────────────────────────────────┤
│  🌐 Google Chrome                      │  ← 应用（最高优先级）
│     /Applications/Google Chrome.app    │
├────────────────────────────────────────┤
│  🔖 Google                             │  ← 书签（中优先级）
│     https://www.google.com             │
├────────────────────────────────────────┤
│  🔖 Google Drive                       │  ← 书签
│     https://drive.google.com           │
├────────────────────────────────────────┤
│  📄 Google Docs                        │  ← 历史（低优先级）
│     https://docs.google.com            │
└────────────────────────────────────────┘
```

**图标说明**:
- 🌐 = 应用程序图标（实际会显示应用的真实图标）
- 🔖 = Chrome 图标（书签）
- 📄 = Chrome 图标（历史）

---

## 📁 数据文件位置

### Chrome 书签
```
~/Library/Application Support/Google/Chrome/Default/Bookmarks
```

**文件格式**: JSON

**关键字段**:
```json
{
  "roots": {
    "bookmark_bar": {
      "children": [
        {
          "type": "url",
          "name": "GitHub",
          "url": "https://github.com"
        }
      ]
    }
  }
}
```

### Chrome 历史
```
~/Library/Application Support/Google/Chrome/Default/History
```

**文件格式**: SQLite3 数据库

**关键表**: `urls`

**关键字段**:
- `url` - 网址
- `title` - 标题
- `visit_count` - 访问次数
- `last_visit_time` - 最后访问时间

---

## ⚙️ 配置选项

### 启用/禁用浏览器数据

在设置中可以控制是否加载书签和历史：

```swift
configManager.browserHistoryEnabled = true  // 默认启用
```

**启用时**:
- ✅ 加载应用
- ✅ 加载书签
- ✅ 加载历史

**禁用时**:
- ✅ 加载应用
- ❌ 不加载书签
- ❌ 不加载历史

---

## 🔐 权限要求

### 完全磁盘访问权限

**需要访问**:
- Chrome 书签文件
- Chrome 历史数据库

**设置路径**:
```
系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Spotlight
```

**无权限时**:
- ⚠️ 无法读取书签
- ⚠️ 无法读取历史
- ✅ 应用搜索仍正常工作

---

## 🚀 性能优化

### 缓存策略

1. **启动时加载**: 所有数据在应用启动时一次性加载到内存
2. **内存缓存**: 使用数组存储，搜索时直接遍历
3. **异步搜索**: 使用 `async/await` 避免阻塞 UI

### 数据限制

- **应用**: 全部加载（通常 100-300 个）
- **书签**: 全部加载（通常 50-200 个）
- **历史**: 最多 500 条（按访问次数排序）

### 结果限制

- **搜索结果**: 最多返回 10 条
- **排序依据**: 优先级权重 + 匹配分数

---

## 📝 代码结构

### 核心类

```swift
class SearchEngine {
    // 缓存
    private var applicationCache: [ApplicationInfo] = []
    private var bookmarksCache: [BookmarkItem] = []
    private var browserHistoryCache: [BrowserHistoryItem] = []
    
    // 加载方法
    func loadApplications()
    func loadBookmarks()
    func loadBrowserHistory()
    
    // 搜索方法
    func searchApplications(query:) -> [SearchResult]
    func searchBookmarks(query:) -> [SearchResult]
    func searchBrowserHistory(query:) -> [SearchResult]
    
    // 主搜索方法
    func search(query:) async -> [SearchResult]
}
```

### 数据模型

```swift
struct SearchResult {
    let title: String
    let subtitle: String?
    let path: String
    let type: SearchResultType
    let icon: NSImage?
    let score: Double
}

struct ApplicationInfo {
    let name: String
    let path: String
    let bundleIdentifier: String?
    let icon: NSImage?
}

struct BookmarkItem {
    let title: String
    let url: String
    let source: BrowserSource
}

struct BrowserHistoryItem {
    let url: String
    let title: String
    let visitCount: Int
    let source: BrowserSource
}
```

---

## 🧪 测试验证

### 测试命令
```bash
.build/Spotlight 2>&1 | tee test_search.log
```

### 验证点

1. **书签加载**
   ```
   🔖 开始加载 Chrome 书签...
   ✅ 书签加载完成，共 X 条记录
   ```

2. **搜索结果**
   ```
   🔍 执行搜索: 'github'
   ✅ 搜索完成，找到 10 个结果
   📋 结果列表:
     1. GitHub Desktop (application)  ← 应用优先
     2. GitHub (url)                  ← 书签次之
     3. GitHub Issues (url)           ← 历史最后
   ```

3. **优先级验证**
   - 应用始终排在最前
   - 书签在应用之后、历史之前
   - 同类型按匹配分数排序

---

## 🎯 使用场景

### 场景 1: 打开常用应用
**输入**: `chrome`
**结果**: Google Chrome 应用排第一

### 场景 2: 访问收藏网站
**输入**: `github`
**结果**: 
1. GitHub Desktop (应用)
2. GitHub 书签
3. 最近访问的 GitHub 页面

### 场景 3: 快速访问文档
**输入**: `语雀`
**结果**:
1. 收藏的语雀文档（书签）
2. 最近访问的语雀页面（历史）

---

**更新时间**: 2025-12-05 22:00  
**状态**: ✅ 已实现三个数据源  
**优先级**: 应用 > 书签 > 历史
