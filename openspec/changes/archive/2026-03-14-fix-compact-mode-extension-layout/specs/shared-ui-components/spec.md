## ADDED Requirements

### Requirement: Extension Layout in Compact Mode
在简约模式下，扩展界面 MUST 能够正确展开显示，不被限制在输入框区域内。

#### Scenario: Extension expands correctly in compact mode
- **WHEN** user opens an extension (e.g., Zed recent projects) in compact mode
- **THEN** the extension content view expands to full available space and is not constrained within the input box area

#### Scenario: Extension content is fully visible in compact mode
- **WHEN** an extension displays a list of items in compact mode
- **THEN** all list items are visible and not compressed or clipped by input box constraints

#### Scenario: Extension layout matches fullscreen mode behavior
- **WHEN** the same extension is opened in both compact mode and fullscreen mode
- **THEN** the extension content layout behavior is consistent between both modes (only window size differs)

#### Scenario: Multiple extensions work correctly in compact mode
- **WHEN** user opens different extensions (Zed, VSCode, etc.) in compact mode
- **THEN** all extensions display their content correctly without layout issues

### Requirement: Mode Switching with Extension Open
当扩展界面已打开时，在简约模式和全屏模式之间切换 MUST 保持扩展内容的正确显示。

#### Scenario: Switch from compact to fullscreen with extension open
- **WHEN** user switches from compact mode to fullscreen mode while an extension is displayed
- **THEN** the extension content remains visible and adjusts to the new window size without layout errors

#### Scenario: Switch from fullscreen to compact with extension open
- **WHEN** user switches from fullscreen mode to compact mode while an extension is displayed
- **THEN** the extension content remains visible and adjusts to compact mode layout correctly

#### Scenario: Extension state preserved during mode switch
- **WHEN** user switches between modes while interacting with an extension
- **THEN** the extension's scroll position and selection state are preserved
