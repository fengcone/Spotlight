# 更新日志

所有重要的项目变更都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增
- 输入框支持编辑快捷键（Command+V/C/X/A/Z）

### 优化
- 文档结构重构，整合为单一 README

## [1.0.1] - 2025-12-25

### 新增
- 词典翻译功能
- IDE 项目集成（CLion、PyCharm、GoLand）
- 魔法后缀过滤（ap、ch、hi、di、cl/qo/py/gl）
- 完整的日志系统
- 使用历史记录和智能排序

### 优化
- 移除 Safari 浏览器历史支持（仅保留 Chrome）
- 搜索性能优化
- 浏览器历史定时刷新（30秒）

### 修复
- 输入框焦点问题
- 窗口位置不固定问题
- 编辑快捷键不工作

## [1.0.0] - 2025-12-05

### 新增
- 全局快捷键支持
- 应用程序搜索
- Chrome 书签搜索
- Chrome 历史搜索
- 模糊匹配算法
- 设置界面
- 配置持久化
- 状态栏菜单

### 技术
- Swift 5.9
- SwiftUI + AppKit
- Carbon Framework
- SQLite3

---

## 版本说明

- **Unreleased** - 未发布的开发中功能
- **1.0.1** - 当前稳定版本
- **1.0.0** - 首个正式版本

## 贡献指南

添加新功能时，请在 `[Unreleased]` 部分记录，并在发布时移至相应版本。
