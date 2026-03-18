## Why

LaunchX 的高级扩展设置界面中，各个设置选项的顶部高度不统一，导致视觉不一致和用户体验下降。这可能是由于字体大小、图标尺寸或内边距设置不一致造成的。统一顶部高度可以提升界面的专业性和一致性。

## What Changes

- 统一所有高级扩展设置界面的顶部高度
- 标准化顶部区域的字体大小、图标尺寸和内边距
- 确保终端设置、剪贴板设置、AI 翻译设置等所有设置页面使用相同的顶部布局规范

## Capabilities

### New Capabilities

无新增功能

### Modified Capabilities

- `shared-ui-components`: 修改设置界面顶部的布局规范，确保所有高级扩展设置页面的顶部高度、字体大小、图标尺寸和内边距完全一致

## Impact

**受影响的组件：**
- 所有高级扩展设置视图（TerminalSettingsView, ClipboardSettingsView, AITranslateSettingsView 等）
- 设置界面的顶部布局代码
- 可能需要创建或更新共享的顶部组件

**回滚计划：**
- 通过 git revert 恢复到修改前的版本
- 纯 UI 布局改动，不涉及数据层，回滚风险低

**测试范围：**
- 检查所有高级扩展设置页面的顶部高度是否一致
- 验证不同设置页面之间切换时的视觉连贯性
