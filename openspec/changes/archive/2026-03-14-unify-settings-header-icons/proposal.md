## Why

高级拓展模块中各个设置详细页面的左上角 icon 和标题文字大小不统一，导致视觉体验不一致。同时，终端和剪贴板的 icon 设计不够美观，需要优化以提升整体 UI 质量。

## What Changes

- 统一所有高级拓展设置详细页面左上角的 icon 尺寸和标题文字大小，以终端设置页面为标准
- 重新设计终端设置的 icon，使其更加美观
- 重新设计剪贴板设置的 icon，使其更加美观
- 确保所有设置页面的视觉风格保持一致

## Capabilities

### New Capabilities

无

### Modified Capabilities

- `shared-ui-components`: 修改设置页面头部组件的 icon 尺寸和标题文字大小规范，确保所有高级拓展设置页面使用统一的样式标准

## Impact

**受影响的组件：**
- 所有高级拓展模块的设置详细页面视图（TerminalSettingsView, ClipboardSettingsView, AITranslateSettingsView 等）
- 设置页面头部的 icon 和标题布局代码
- icon 资源文件（终端和剪贴板的 icon 图标）

**回滚计划：**
- 保留原有的 icon 资源文件作为备份
- 代码修改通过 git 版本控制可随时回滚
