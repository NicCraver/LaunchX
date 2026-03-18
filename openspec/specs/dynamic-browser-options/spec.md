## ADDED Requirements

### Requirement: 动态生成打开浏览器选项列表
系统 SHALL 基于已安装的浏览器动态生成"打开浏览器"选项列表，而不是硬编码固定选项。

#### Scenario: 显示所有已安装的浏览器
- **WHEN** 用户打开书签搜索设置页面
- **THEN** "打开浏览器"下拉菜单 SHALL 显示所有已安装的浏览器选项

#### Scenario: 隐藏未安装的浏览器
- **WHEN** 某个浏览器未安装在系统中
- **THEN** 该浏览器 SHALL NOT 出现在"打开浏览器"选项列表中

#### Scenario: 保留特殊选项
- **WHEN** 生成选项列表时
- **THEN** 系统 SHALL 始终包含"书签浏览器"和"默认浏览器"两个特殊选项

### Requirement: 支持所有 BookmarkSource 定义的浏览器
系统 SHALL 支持打开所有在 BookmarkSource 枚举中定义的浏览器。

#### Scenario: 支持 Safari 浏览器
- **WHEN** 用户选择 Safari 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Safari 打开

#### Scenario: 支持 Chrome 浏览器
- **WHEN** 用户选择 Chrome 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Chrome 打开

#### Scenario: 支持 Brave 浏览器
- **WHEN** 用户选择 Brave 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Brave 打开

#### Scenario: 支持 Arc 浏览器
- **WHEN** 用户选择 Arc 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Arc 打开

#### Scenario: 支持 Edge 浏览器
- **WHEN** 用户选择 Edge 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Edge 打开

#### Scenario: 支持 Vivaldi 浏览器
- **WHEN** 用户选择 Vivaldi 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Vivaldi 打开

#### Scenario: 支持 Opera 浏览器
- **WHEN** 用户选择 Opera 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Opera 打开

#### Scenario: 支持 Helium 浏览器
- **WHEN** 用户选择 Helium 作为打开浏览器
- **THEN** 点击书签 SHALL 使用 Helium 打开

### Requirement: 向后兼容现有用户设置
系统 SHALL 保持与现有用户设置的向后兼容性。

#### Scenario: 保留现有用户选择
- **WHEN** 用户升级到新版本
- **THEN** 之前保存的"打开浏览器"设置 SHALL 保持不变

#### Scenario: 处理已卸载的浏览器
- **WHEN** 用户之前选择的浏览器已被卸载
- **THEN** 系统 SHALL 自动回退到"默认浏览器"选项

#### Scenario: 加载设置失败时的默认值
- **WHEN** 无法从 UserDefaults 加载设置
- **THEN** 系统 SHALL 使用"默认浏览器"作为默认值

### Requirement: 使用 BookmarkSource 作为数据源
系统 SHALL 使用 BookmarkSource 枚举作为浏览器选项的唯一数据源。

#### Scenario: 复用浏览器检测逻辑
- **WHEN** 检测浏览器是否已安装
- **THEN** 系统 SHALL 使用 BookmarkSource.isInstalled 属性

#### Scenario: 复用浏览器图标
- **WHEN** 显示浏览器图标
- **THEN** 系统 SHALL 使用 BookmarkSource.icon 属性

#### Scenario: 复用浏览器显示名称
- **WHEN** 显示浏览器名称
- **THEN** 系统 SHALL 使用 BookmarkSource.displayName 属性

### Requirement: 正确处理特殊打开方式
系统 SHALL 正确处理"书签浏览器"和"默认浏览器"两个特殊选项。

#### Scenario: 使用书签浏览器打开
- **WHEN** 用户选择"书签浏览器"选项
- **THEN** 点击书签 SHALL 使用该书签所属的浏览器打开

#### Scenario: 使用默认浏览器打开
- **WHEN** 用户选择"默认浏览器"选项
- **THEN** 点击书签 SHALL 使用系统默认浏览器打开

#### Scenario: 默认浏览器未设置时的回退
- **WHEN** 系统未设置默认浏览器
- **THEN** 系统 SHALL 使用 Safari 作为回退选项
