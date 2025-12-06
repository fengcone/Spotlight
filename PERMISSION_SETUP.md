# 权限设置指南

## 🔐 需要的权限

Spotlight 需要两个权限：

### 1. ✅ 辅助功能权限（必需）
**用途**: 监听全局快捷键（Command+Space）

**状态**: 应该已经授权

---

### 2. 📁 完全磁盘访问权限（可选，但推荐）
**用途**: 
- 读取 Chrome 书签
- 读取 Chrome 浏览历史

**状态**: ⚠️ 未授权（需要手动设置）

---

## 📋 详细设置步骤

### 方法 1: 通过系统设置（推荐）

#### 步骤 1: 打开系统设置
```
点击屏幕左上角  → 系统设置
```

或者按 `Command + 空格` 搜索 "系统设置"

---

#### 步骤 2: 进入隐私与安全性
```
系统设置 → 隐私与安全性
```

在左侧菜单找到 "隐私与安全性"

---

#### 步骤 3: 选择完全磁盘访问权限
```
隐私与安全性 → 完全磁盘访问权限
```

在右侧列表找到 "完全磁盘访问权限" 并点击

---

#### 步骤 4: 添加 Spotlight 应用

1. **点击左下角的锁图标** 🔒
   - 输入管理员密码解锁

2. **点击 "+" 按钮** ➕
   - 位于应用列表下方

3. **找到 Spotlight 应用**
   
   **方法 A: 如果你从终端运行**
   ```
   位置: /Users/你的用户名/WorkSpaceL/Spotlight/.build/Spotlight
   ```
   
   在文件选择器中：
   - 按 `Command + Shift + G` 输入路径
   - 或者手动导航到 WorkSpaceL/Spotlight/.build/
   - 选择 `Spotlight` 文件（没有扩展名）

   **方法 B: 如果你创建了应用包**
   ```
   位置: /Applications/Spotlight.app
   ```

4. **点击"打开"按钮**

5. **确认 Spotlight 出现在列表中**
   - 左侧应该有一个勾选框 ✅
   - 确保勾选框被选中

6. **点击左下角的锁图标** 🔒
   - 再次锁定设置

---

#### 步骤 5: 重启 Spotlight

**完全退出当前运行的 Spotlight**:
```bash
# 在终端按 Ctrl+C 退出
# 或者强制退出
killall Spotlight
```

**重新启动**:
```bash
.build/Spotlight
```

---

### 方法 2: 使用快捷命令

你也可以使用终端命令打开设置页面：

```bash
# 打开完全磁盘访问权限设置
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
```

然后按照上面的步骤 4-5 操作。

---

## 🎯 验证权限是否生效

### 重新运行 Spotlight
```bash
.build/Spotlight 2>&1 | tee test_permission.log
```

### 预期的成功日志

**授权成功**:
```
🔖 开始加载 Chrome 书签...
✅ 书签加载完成，共 150 条记录  ← 看到数量 > 0

📚 开始加载浏览器历史...
✅ 浏览器历史加载完成，共 500 条记录  ← 看到数量 > 0
```

**仍然失败**:
```
🔖 开始加载 Chrome 书签...
⚠️ 无法读取 Chrome 书签: The file "Bookmarks" couldn't be opened...

📋 解决方法：
1️⃣  打开 '系统设置'
2️⃣  进入 '隐私与安全性'
...
```

---

## 🔍 常见问题

### Q1: 找不到 Spotlight 应用文件？

**A**: 应用文件位置取决于你的构建方式：

**从终端运行**:
```bash
# 查看当前位置
pwd
# 应该显示: /Users/你的用户名/WorkSpaceL/Spotlight

# 应用位置
ls -la .build/Spotlight
# 应该看到可执行文件
```

**完整路径**:
```
/Users/你的用户名/WorkSpaceL/Spotlight/.build/Spotlight
```

**提示**: 在文件选择器中，按 `Command + Shift + G` 可以直接输入路径。

---

### Q2: 添加后仍然没有权限？

**可能原因**:
1. 没有重启 Spotlight
2. 添加的文件不正确
3. 勾选框没有选中

**解决方法**:
1. **确认勾选框被选中** ✅
2. **完全退出 Spotlight**
   ```bash
   killall Spotlight
   # 或在终端按 Ctrl+C
   ```
3. **等待 5 秒**
4. **重新启动**
   ```bash
   .build/Spotlight
   ```

---

### Q3: 系统设置中看不到"完全磁盘访问权限"？

**A**: 确保你的 macOS 版本 ≥ 10.14（Mojave）

**检查版本**:
```bash
sw_vers
```

如果版本太旧，升级 macOS 或者浏览器数据功能将不可用（应用搜索仍正常）。

---

### Q4: Chrome 书签/历史文件不存在？

**检查 Chrome 是否安装**:
```bash
ls -la "/Applications/Google Chrome.app"
```

**检查数据文件**:
```bash
# 书签
ls -la ~/Library/Application\ Support/Google/Chrome/Default/Bookmarks

# 历史
ls -la ~/Library/Application\ Support/Google/Chrome/Default/History
```

**如果不存在**:
- 确保 Chrome 已安装
- 确保至少打开过一次 Chrome
- 确保使用的是默认 Profile（Default）

---

### Q5: 我使用的是其他 Chrome Profile？

**A**: 默认读取 `Default` Profile

**如果使用其他 Profile**:
```bash
# 查看所有 Profile
ls -la ~/Library/Application\ Support/Google/Chrome/

# 可能看到:
# Default/
# Profile 1/
# Profile 2/
```

**临时方案**: 
目前只支持 Default Profile。如果需要其他 Profile，可以暂时切换到 Default。

**未来改进**: 
可以添加配置选项支持多 Profile。

---

### Q6: 不想授予完全磁盘访问权限？

**A**: 完全可以！

**影响**:
- ❌ 无法搜索 Chrome 书签
- ❌ 无法搜索浏览历史
- ✅ 应用搜索完全正常

**选择**:
如果你主要用来搜索应用，可以不授权。

**替代方案**:
手动禁用浏览器数据搜索：
```swift
// 在设置中关闭
configManager.browserHistoryEnabled = false
```

---

## 📱 macOS 版本差异

### macOS 14 (Sonoma)
```
系统设置 → 隐私与安全性 → 完全磁盘访问权限
```

### macOS 13 (Ventura)
```
系统设置 → 隐私与安全性 → 完全磁盘访问权限
```

### macOS 12 (Monterey)
```
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问权限
```

### macOS 11 (Big Sur)
```
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问权限
```

---

## 🎨 视觉指南

### 系统设置截图位置

1. **隐私与安全性**
   ```
   [系统设置]
   ├── 通用
   ├── 外观
   ├── 辅助功能
   ├── 控制中心
   ├── Siri 与聚焦
   ├── 隐私与安全性  ← 点这里
   ```

2. **完全磁盘访问权限**
   ```
   [隐私与安全性]
   ├── 定位服务
   ├── 联系人
   ├── 日历
   ├── 提醒事项
   ├── 照片
   ├── 完全磁盘访问权限  ← 点这里
   ├── 辅助功能
   ```

3. **应用列表**
   ```
   [完全磁盘访问权限]
   
   允许下列应用访问所有磁盘上的数据
   
   ☐  Terminal
   ☐  iTerm
   ☑️  Spotlight  ← 添加并勾选
   
   [🔒] [+] [-]
   ```

---

## ✅ 完整检查清单

在添加权限前：
- [ ] 确认 Spotlight 可执行文件位置
- [ ] 确认 Chrome 已安装
- [ ] 确认 Chrome 至少打开过一次

添加权限时：
- [ ] 打开系统设置
- [ ] 进入隐私与安全性
- [ ] 选择完全磁盘访问权限
- [ ] 解锁（点击左下角🔒）
- [ ] 点击 + 按钮
- [ ] 找到并添加 Spotlight
- [ ] 确认勾选框被选中 ✅
- [ ] 锁定（点击左下角🔒）

添加权限后：
- [ ] 完全退出 Spotlight（Ctrl+C 或 killall）
- [ ] 等待 5 秒
- [ ] 重新启动 Spotlight
- [ ] 查看日志确认成功

验证成功：
- [ ] 看到 "书签加载完成，共 X 条记录"（X > 0）
- [ ] 看到 "浏览器历史加载完成，共 X 条记录"（X > 0）
- [ ] 搜索时能看到书签和历史结果

---

## 🆘 还是不行？

如果按照以上步骤仍然无法解决，请提供以下信息：

1. **macOS 版本**
   ```bash
   sw_vers
   ```

2. **Chrome 版本**
   ```bash
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version
   ```

3. **文件是否存在**
   ```bash
   ls -la ~/Library/Application\ Support/Google/Chrome/Default/Bookmarks
   ls -la ~/Library/Application\ Support/Google/Chrome/Default/History
   ```

4. **完整的启动日志**
   ```bash
   .build/Spotlight 2>&1 | tee debug.log
   ```

5. **系统设置截图**
   - 隐私与安全性 → 完全磁盘访问权限的页面

---

**更新时间**: 2025-12-05 22:05  
**适用版本**: macOS 11.0+  
**Chrome 版本**: 所有版本
