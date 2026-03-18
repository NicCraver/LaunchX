## ADDED Requirements

### Requirement: Settings Header Height Consistency
所有高级扩展设置页面的顶部区域 MUST 具有统一的高度和视觉样式。

#### Scenario: All settings pages have consistent header height
- **WHEN** user navigates between different advanced extension settings pages (Terminal, Clipboard, AI Translate, etc.)
- **THEN** all page headers MUST have identical height

#### Scenario: Header icon size is consistent across all pages
- **WHEN** any advanced extension settings page is displayed
- **THEN** the header icon size MUST be consistent across all pages

#### Scenario: Header title font size is consistent across all pages
- **WHEN** any advanced extension settings page is displayed
- **THEN** the header title font size MUST be consistent across all pages

#### Scenario: Header padding and spacing is consistent across all pages
- **WHEN** any advanced extension settings page is displayed
- **THEN** the header padding (top, bottom, leading, trailing) and spacing between icon and title MUST be consistent across all pages

### Requirement: Settings Header Style Standards
系统 SHALL 定义并应用统一的设置页面顶部样式标准。

#### Scenario: Standard icon size is defined
- **WHEN** implementing or updating a settings page header
- **THEN** the icon size MUST conform to the defined standard (e.g., 32x32 points)

#### Scenario: Standard title font is defined
- **WHEN** implementing or updating a settings page header
- **THEN** the title font size and weight MUST conform to the defined standard

#### Scenario: Standard spacing values are defined
- **WHEN** implementing or updating a settings page header
- **THEN** the spacing between elements and padding values MUST conform to the defined standards

### Requirement: Visual Consistency Verification
系统 MUST 确保所有现有和未来的设置页面都遵循统一的顶部样式规范。

#### Scenario: Existing settings pages are updated to match standards
- **WHEN** the style standards are defined
- **THEN** all existing advanced extension settings pages MUST be updated to match the standards

#### Scenario: New settings pages follow the standards
- **WHEN** a new advanced extension settings page is created
- **THEN** the page header MUST follow the established style standards from the beginning
