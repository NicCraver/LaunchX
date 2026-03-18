## Why

当前"打开浏览器"设置项硬编码了 Safari 和 Chrome 两个选项，而"搜索浏览器"已经支持动态检测 8 个浏览器（Safari、Chrome、Brave、Arc、Edge、Vivaldi、Opera、Helium）。这导致用户体验不一致：用户可以搜索所有已安装浏览器的书签，但只能用 Safari 或 Chrome 打开。需要让"打开浏览器"设置也动态显示已安装的浏览器，提供一致的用户体验。

## What Changes

- 将 `BookmarkOpenWith` 枚举从硬编码的 4 个选项改为动态生成，基于 `BookmarkSource` 的已安装浏览器
- 保留"书签浏览器"和"默认浏览器"两个特殊选项
- 动态添加所有已安装浏览器的选项（Safari、Chrome、Brave、Arc、Edge、Vivaldi、Opera、Helium）
- 更新 UI Picker 以支持动态选项列表
- 更新书签打开逻辑以支持所有浏览器
- 处理用户之前保存的设置迁移（如果之前选择的浏览器已卸载）

## Capabilities

### New Capabilities
- `dynamic-browser-options`: 动态生成"打开浏览器"选项列表，基于系统已安装的浏览器

### Modified Capabilities
<!-- 无现有 capability 的需求变更，这是实现细节的改进 -->

## Impact

### 受影响的代码
- `LaunchX/Services/BookmarkService.swift`
  - `BookmarkOpenWith` 枚举需要重构为支持动态选项
  - `BookmarkSettings` 的 `openWith` 属性类型可能需要调整
  - `open(_:)` 方法需要支持所有浏览器

- `LaunchX/Views/AdvancedExtensionsView.swift`
  - `BookmarkSearchSettingsView` 中的 Picker 需要使用动态选项列表

### 数据迁移
- 需要处理用户已保存的 `openWith` 设置
- 如果用户之前选择的浏览器已卸载，需要回退到"默认浏览器"

### 回滚计划
- 保持 `BookmarkSettings` 的 Codable 兼容性
- 如果出现问题，可以回退到硬编码的 Safari 和 Chrome 选项
- 用户设置通过 UserDefaults 存储，可以手动清除重置
