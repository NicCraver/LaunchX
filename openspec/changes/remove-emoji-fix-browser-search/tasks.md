## 1. 移除表情包搜索模块

- [x] 1.1 删除 `LaunchX/Services/MemeSearchService.swift` 文件
- [x] 1.2 删除 `LaunchX/Views/MemeSearchSettingsView.swift` 文件
- [x] 1.3 删除 `LaunchX/Models/MemeItem.swift` 文件
- [x] 1.4 从 `AdvancedExtensionsView.swift` 中移除表情包搜索设置项的引用

## 2. 移除表情包收藏模块

- [x] 2.1 删除 `LaunchX/Services/MemeFavoriteService.swift` 文件
- [x] 2.2 删除 `LaunchX/Views/MemeFavoriteSettingsView.swift` 文件
- [x] 2.3 从 `AdvancedExtensionsView.swift` 中移除表情包收藏设置项的引用

## 3. 扩展 BookmarkSource 枚举以支持多浏览器

- [x] 3.1 在 `BookmarkService.swift` 中扩展 `BookmarkSource` 枚举，添加 `brave`、`arc`、`edge`、`vivaldi`、`opera` 等选项
- [x] 3.2 为 `BookmarkSource` 添加 `bundleIdentifier` 计算属性，返回对应浏览器的 Bundle ID
- [x] 3.3 为 `BookmarkSource` 添加 `bookmarkPath` 计算属性，返回对应浏览器的书签文件路径
- [x] 3.4 为 `BookmarkSource` 添加 `isInstalled` 计算属性，使用 `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` 检测浏览器是否安装

## 4. 修改书签搜索设置 UI

- [x] 4.1 在 `AdvancedExtensionsView.swift` 的 `BookmarkSearchSettingsView` 中，修改浏览器选项渲染逻辑
- [x] 4.2 使用 `BookmarkSource.allCases.filter { $0.isInstalled }` 仅显示已安装的浏览器
- [x] 4.3 更新 `BrowserToggleRow` 组件，确保动态浏览器列表正确显示

## 5. 实现 Chromium 系浏览器书签读取

- [x] 5.1 在 `BookmarkService` 中扩展书签读取逻辑，支持新增的 Chromium 系浏览器
- [x] 5.2 验证 Chromium 系浏览器的书签路径格式一致性（`~/Library/Application Support/<BrowserName>/Default/Bookmarks`）
- [x] 5.3 确保 JSON 解析逻辑适用于所有 Chromium 系浏览器

## 6. 测试与验证

- [x] 6.1 验证表情包搜索和收藏功能完全移除，应用可正常编译运行
- [x] 6.2 测试 Safari 浏览器检测和书签读取功能
- [x] 6.3 测试 Chrome 浏览器检测和书签读取功能
- [x] 6.4 测试第三方 Chromium 系浏览器（如 Brave、Arc）的检测和书签读取功能
- [x] 6.5 验证未安装的浏览器不会出现在设置选项中
- [x] 6.6 验证书签搜索的其他功能（搜索、打开书签）正常工作
