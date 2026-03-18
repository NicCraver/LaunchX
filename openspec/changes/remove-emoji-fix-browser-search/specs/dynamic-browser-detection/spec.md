## ADDED Requirements

### Requirement: System SHALL detect installed browsers

系统必须能够检测 macOS 系统中已安装的浏览器，并仅在书签搜索配置中显示已安装的浏览器选项。

#### Scenario: Safari is installed

- **WHEN** 系统检测到 Safari 浏览器已安装（Bundle ID: `com.apple.Safari`）
- **THEN** 书签搜索配置中必须显示 Safari 选项

#### Scenario: Chrome is installed

- **WHEN** 系统检测到 Chrome 浏览器已安装（Bundle ID: `com.google.Chrome`）
- **THEN** 书签搜索配置中必须显示 Chrome 选项

#### Scenario: Third-party Chromium browser is installed

- **WHEN** 系统检测到第三方 Chromium 系浏览器已安装（如 Brave、Arc、Edge、Vivaldi、Opera、Helium）
- **THEN** 书签搜索配置中必须显示该浏览器选项

#### Scenario: Browser is not installed

- **WHEN** 系统检测到某浏览器未安装
- **THEN** 书签搜索配置中不得显示该浏览器选项

### Requirement: System SHALL support multiple Chromium-based browsers

系统必须支持主流 Chromium 系浏览器的书签读取，包括但不限于 Chrome、Brave、Arc、Edge、Vivaldi、Opera。

#### Scenario: Read Chromium browser bookmarks

- **WHEN** 用户启用某个 Chromium 系浏览器作为书签来源
- **THEN** 系统必须从标准路径 `~/Library/Application Support/<BrowserName>/Default/Bookmarks` 读取书签数据

#### Scenario: Parse Chromium bookmark format

- **WHEN** 系统读取 Chromium 系浏览器的书签文件
- **THEN** 系统必须正确解析 JSON 格式的书签数据

### Requirement: Browser detection SHALL use NSWorkspace API

系统必须使用 `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` API 检测浏览器是否安装。

#### Scenario: Detect browser by Bundle ID

- **WHEN** 系统需要检测浏览器是否安装
- **THEN** 系统必须通过 Bundle Identifier 查询 NSWorkspace API
- **THEN** 如果 API 返回非 nil URL，则判定浏览器已安装

### Requirement: UI SHALL dynamically render browser options

书签搜索设置界面必须根据检测结果动态渲染浏览器选项列表。

#### Scenario: Show only installed browsers

- **WHEN** 用户打开书签搜索设置界面
- **THEN** 界面必须仅显示系统中已安装的浏览器选项
- **THEN** 未安装的浏览器不得出现在选项列表中

#### Scenario: Update options when browser is installed

- **WHEN** 用户安装新浏览器后重新打开设置界面
- **THEN** 新安装的浏览器必须出现在选项列表中
