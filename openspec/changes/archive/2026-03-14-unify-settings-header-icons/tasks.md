## 1. 调研现有代码

- [x] 1.1 查找 TerminalSettingsView 文件，记录其头部 icon 尺寸和标题文字大小的具体数值
- [x] 1.2 查找所有高级拓展设置详细页面视图文件（ClipboardSettingsView, AITranslateSettingsView 等）
- [x] 1.3 记录每个设置页面当前的头部 icon 尺寸和标题文字大小

## 2. 统一头部样式

- [x] 2.1 修改 ClipboardSettingsView 的头部 icon 尺寸和标题文字大小，使其与 TerminalSettingsView 一致
- [x] 2.2 修改 AITranslateSettingsView 的头部 icon 尺寸和标题文字大小，使其与 TerminalSettingsView 一致
- [x] 2.3 修改其他高级拓展设置页面的头部 icon 尺寸和标题文字大小，使其与 TerminalSettingsView 一致

## 3. 重新设计 Icon

- [x] 3.1 备份终端设置的原有 icon 资源文件
- [x] 3.2 设计并替换终端设置的新 icon（使用 SF Symbols 或自定义图标）
- [x] 3.3 备份剪贴板设置的原有 icon 资源文件
- [x] 3.4 设计并替换剪贴板设置的新 icon（使用 SF Symbols 或自定义图标）

## 4. 验证和测试

- [x] 4.1 运行应用，检查所有高级拓展设置页面的头部样式是否统一
- [x] 4.2 验证终端和剪贴板的新 icon 是否正确显示且美观
- [x] 4.3 在不同页面间切换，确认视觉一致性
