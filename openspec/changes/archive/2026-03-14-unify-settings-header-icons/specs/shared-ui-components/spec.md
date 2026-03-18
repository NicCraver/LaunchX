## ADDED Requirements

### Requirement: Settings Header Style Consistency
所有高级拓展设置详细页面的头部 MUST 使用统一的 icon 尺寸和标题文字大小。

#### Scenario: Header icon size is consistent
- **WHEN** any advanced extension settings detail page is displayed
- **THEN** the header icon size MUST match the size used in TerminalSettingsView

#### Scenario: Header title font size is consistent
- **WHEN** any advanced extension settings detail page is displayed
- **THEN** the header title font size MUST match the size used in TerminalSettingsView

#### Scenario: All settings pages use same header style
- **WHEN** user navigates between different advanced extension settings pages (Terminal, Clipboard, AI Translate, etc.)
- **THEN** all pages display headers with identical icon size and title font size

### Requirement: Terminal Icon Design
终端设置的 icon MUST 使用更美观的设计。

#### Scenario: Terminal icon is visually appealing
- **WHEN** TerminalSettingsView is displayed
- **THEN** the terminal icon MUST use an improved design that is more visually appealing than the current version

### Requirement: Clipboard Icon Design
剪贴板设置的 icon MUST 使用更美观的设计。

#### Scenario: Clipboard icon is visually appealing
- **WHEN** ClipboardSettingsView is displayed
- **THEN** the clipboard icon MUST use an improved design that is more visually appealing than the current version
