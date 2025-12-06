# macOS 权限配置指南

## 🔐 为什么需要这些权限？

Spotlight 需要访问系统的某些受保护区域才能正常工作：

1. **辅助功能权限** - 用于监听全局快捷键
2. **完全磁盘访问权限** - 用于读取 Chrome 书签和历史记录

## 📋 权限配置步骤

### 1. 辅助功能权限（必需）

**作用**：允许 Spotlight 监听系统级快捷键（如 Command+Space）

**配置步骤**：
1. 打开 **系统设置**
2. 进入 **隐私与安全性** → **辅助功能**
3. 点击 **+** 按钮
4. 找到并选择 **Spotlight.app**
5. 确保开关为 **开启状态**

**截图位置**：
```
系统设置
  └─ 隐私与安全性
      └─ 辅助功能
          └─ [+] Spotlight ☑️
```

### 2. 完全磁盘访问权限（推荐）

**作用**：允许 Spotlight 读取 Chrome 的书签和历史记录文件

**配置步骤**：
1. 打开 **系统设置**
2. 进入 **隐私与安全性** → **完全磁盘访问权限**
3. 点击 **+** 按钮
4. 找到并选择 **Spotlight.app**
5. 确保开关为 **开启状态**

**截图位置**：
```
系统设置
  └─ 隐私与安全性
      └─ 完全磁盘访问权限
          └─ [+] Spotlight ☑️
```

**如果不授予此权限**：
- ✅ 应用可以正常启动
- ✅ 可以搜索本地应用程序
- ❌ **无法读取 Chrome 书签**
- ❌ **无法读取 Chrome 历史记录**

## 🔍 如何验证权限已生效

### 方法1: 查看日志

打包后的应用会在 `~/Library/Logs/Spotlight/` 目录生成日志：

```bash
# 查看今天的日志
tail -50 ~/Library/Logs/Spotlight/spotlight-$(date +%Y-%m-%d).log
```

**正常情况**（有权限）：
```
[2025-12-06 08:30:15] [INFO] ✅ Chrome 书签加载完成，共 127 条记录
[2025-12-06 08:30:16] [INFO] ✅ 浏览器历史加载完成，共 500 条记录
```

**异常情况**（无权限）：
```
[2025-12-06 08:30:15] [WARN] ⚠️ Chrome 书签文件不存在
[2025-12-06 08:30:15] [WARN] ⚠️ 无法读取 Chrome 书签: Permission denied
[2025-12-06 08:30:16] [WARN] ⚠️ Chrome 历史文件不存在
```

### 方法2: 测试搜索

1. 启动 Spotlight
2. 按 Command+Space 呼出搜索窗口
3. 输入你的 Chrome 书签中的关键词
4. 如果能看到书签结果，说明权限配置成功

## ⚠️ 常见问题

### Q1: 授权后仍然无法读取书签？

**解决方法**：
1. 完全退出 Spotlight 应用（右键状态栏图标 → 退出）
2. 重新启动 Spotlight
3. macOS 需要应用重启才能应用新的权限设置

### Q2: 找不到 Spotlight.app？

**解决方法**：
1. 确保已经将应用安装到 `/Applications/` 或 `~/Applications/`
2. 在 Finder 中按 Command+Shift+G，输入完整路径
3. 或者在终端运行：
   ```bash
   open ~/Applications/
   ```

### Q3: 授权时提示"无法验证开发者"？

这是因为应用使用了 ad-hoc 签名（自签名），而不是 Apple 开发者证书签名。

**解决方法**：
1. 右键点击 Spotlight.app
2. 选择"打开"
3. 在弹出的对话框中点击"打开"
4. 之后就可以正常运行了

或者使用终端：
```bash
# 移除隔离属性
xattr -d com.apple.quarantine ~/Applications/Spotlight.app
```

### Q4: 权限列表中没有 Spotlight？

**解决方法**：
1. 先运行一次 Spotlight
2. 当系统提示需要权限时，点击"打开系统设置"
3. 或者手动添加：在权限设置页面点击 **+** 按钮，浏览到 Spotlight.app

### Q5: 能读取历史但读不到书签？

检查 Chrome 书签文件是否存在：
```bash
ls -la ~/Library/Application\ Support/Google/Chrome/Default/Bookmarks
```

如果文件存在但仍然读不到：
1. 确认"完全磁盘访问权限"已授予
2. 重启 Spotlight 应用
3. 检查日志文件中的错误信息

## 🛡️ 安全说明

### Entitlements 文件说明

Spotlight 使用 `Spotlight.entitlements` 文件声明所需权限：

```xml
<!-- 禁用 App Sandbox -->
<key>com.apple.security.app-sandbox</key>
<false/>

<!-- 允许读取所有文件 -->
<key>com.apple.security.files.all</key>
<true/>
```

**为什么禁用沙盒？**
- Spotlight 需要访问系统的多个位置（应用目录、Chrome 数据目录等）
- 沙盒模式会严格限制文件访问，导致功能无法使用
- 作为工具类应用，需要用户手动授予"完全磁盘访问权限"

**这样安全吗？**
- ✅ 应用是开源的，代码完全可见
- ✅ 只读取必要的文件（书签、历史）
- ✅ 不会修改或上传任何数据
- ✅ 所有操作都有日志记录
- ⚠️ 需要用户手动授予权限，系统会提示

## 📝 权限撤销

如果不再使用 Spotlight，可以撤销权限：

1. 打开 **系统设置** → **隐私与安全性**
2. 在 **辅助功能** 和 **完全磁盘访问权限** 中
3. 找到 Spotlight，取消勾选
4. 或者点击 **-** 按钮删除

## 🔄 重新授权

如果误删除了权限：

1. 完全退出 Spotlight
2. 删除 `~/Library/Application Support/Spotlight/` 配置目录（可选）
3. 重新启动 Spotlight
4. 按照上述步骤重新授权

## 📚 技术细节

### 权限文件位置
- **Entitlements**: `Spotlight.entitlements`
- **Info.plist**: `.build/Spotlight.app/Contents/Info.plist`

### Chrome 数据文件位置
- **书签**: `~/Library/Application Support/Google/Chrome/Default/Bookmarks`
- **历史**: `~/Library/Application Support/Google/Chrome/Default/History`

### 代码签名
```bash
# 查看应用的签名信息
codesign -d --entitlements - .build/Spotlight.app

# 查看应用的权限
codesign -d --entitlements :- .build/Spotlight.app 2>&1 | xmllint --format -
```

---

**配置好权限后，Spotlight 就能完整访问 Chrome 的书签和历史记录了！** 🚀
