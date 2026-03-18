## ADDED Requirements

### Requirement: 全局纯文本粘贴快捷键
系统 SHALL 支持全局纯文本粘贴快捷键，该快捷键 MUST 能够在任何时候触发，无需依赖剪贴板面板的打开状态。

#### Scenario: 快捷键直接触发纯文本粘贴
- **WHEN** 用户按下配置的纯文本粘贴快捷键
- **THEN** 系统 MUST 读取当前系统剪贴板的最新内容
- **THEN** 系统 MUST 将内容转换为纯文本格式（去除所有富文本格式）
- **THEN** 系统 MUST 模拟 Cmd+V 粘贴操作将纯文本粘贴到当前焦点应用

#### Scenario: 快捷键在面板未打开时工作
- **WHEN** 剪贴板面板未打开
- **WHEN** 用户按下纯文本粘贴快捷键
- **THEN** 系统 MUST 正常执行纯文本粘贴操作
- **THEN** 系统 MUST NOT 要求用户先打开面板或选择项目

### Requirement: 富文本格式保留
系统 SHALL 在保存剪贴板项时保留原始的富文本格式信息，并在粘贴时根据用户选择决定是否保留格式。

#### Scenario: 保存富文本内容
- **WHEN** 系统监测到剪贴板中有富文本内容（包含 RTF、HTML 等格式）
- **THEN** 系统 MUST 同时保存纯文本内容和富文本格式数据
- **THEN** 系统 MUST 确保富文本格式数据完整可恢复

#### Scenario: 直接粘贴保留格式
- **WHEN** 用户在剪贴板面板中按回车键或双击项目
- **THEN** 系统 MUST 将内容以原始格式写入系统剪贴板
- **THEN** 系统 MUST 保留所有富文本格式信息（RTF、HTML、样式等）
- **THEN** 粘贴到目标应用后 MUST 保持原始格式

#### Scenario: 纯文本粘贴去除格式
- **WHEN** 用户在剪贴板面板中按 ⌘+回车键
- **THEN** 系统 MUST 将内容转换为纯文本格式
- **THEN** 系统 MUST 去除所有富文本格式信息
- **THEN** 粘贴到目标应用后 MUST 只包含纯文本内容

### Requirement: 剪贴板数据模型扩展
ClipboardItem 数据模型 SHALL 支持存储富文本格式数据。

#### Scenario: 存储多种格式
- **WHEN** 保存剪贴板项
- **THEN** 系统 MUST 能够存储纯文本内容（textContent）
- **THEN** 系统 MUST 能够存储富文本数据（RTF、HTML 等格式）
- **THEN** 系统 MUST 确保不同格式数据之间不会相互干扰

#### Scenario: 读取富文本数据
- **WHEN** 需要恢复剪贴板项的原始格式
- **THEN** 系统 MUST 能够读取并恢复所有保存的格式数据
- **THEN** 系统 MUST 按照正确的优先级顺序写入系统剪贴板

### Requirement: 剪贴板写入逻辑
系统 SHALL 根据 asPlainText 参数决定写入剪贴板的内容格式。

#### Scenario: 写入富文本格式
- **WHEN** asPlainText 参数为 false
- **WHEN** 剪贴板项包含富文本数据
- **THEN** 系统 MUST 将所有格式数据写入系统剪贴板
- **THEN** 系统 MUST 按照 macOS 剪贴板的标准格式优先级写入

#### Scenario: 写入纯文本格式
- **WHEN** asPlainText 参数为 true
- **THEN** 系统 MUST 只将纯文本内容写入系统剪贴板
- **THEN** 系统 MUST NOT 写入任何富文本格式数据
