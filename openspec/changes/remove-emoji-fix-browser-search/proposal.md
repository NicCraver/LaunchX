## Why

表情包搜索和表情包收藏功能使用频率过低，维护成本不值得。同时，书签搜索模块的浏览器选项硬编码为 Safari 和 Chrome，无法自动检测用户安装的其他浏览器（如 Helium），限制了功能的实用性。

## What Changes

- 移除表情包搜索模块的所有代码和 UI
- 移除表情包收藏模块的所有代码和 UI
- 修改书签搜索模块，使其能够动态检测系统中已安装的浏览器，而不是硬编码浏览器列表
- 清理相关的设置项、快捷键绑定和用户数据存储逻辑

## Capabilities

### New Capabilities

- `dynamic-browser-detection`: 动态检测系统中已安装的浏览器，自动在书签搜索配置中显示可用选项

### Modified Capabilities

无现有规范需要修改。

## Impact

**受影响的组件：**

- `LaunchX/Services/MemeSearchService.swift` - 删除
- `LaunchX/Services/MemeFavoriteService.swift` - 删除
- `LaunchX/Views/MemeSearchSettingsView.swift` - 删除
- `LaunchX/Views/MemeFavoriteSettingsView.swift` - 删除
- `LaunchX/Models/MemeItem.swift` - 删除
- `LaunchX/Services/BookmarkService.swift` - 修改浏览器检测逻辑
- `LaunchX/Views/AdvancedExtensionsView.swift` - 移除表情包相关设置，修改书签浏览器选项 UI

**用户数据：**

- 表情包收藏的本地数据（`~/Library/Application Support/LaunchX/MemeFavorites/`）将不再被应用访问
- 用户需要手动删除这些数据（如果需要）

**回滚计划：**

- 通过 Git 恢复删除的文件
- 重新添加表情包模块到设置界面
- 恢复书签搜索的硬编码浏览器列表
