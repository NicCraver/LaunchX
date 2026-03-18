## 1. 创建 BookmarkOpenWithOption 枚举

- [x] 1.1 在 `BookmarkService.swift` 中创建 `BookmarkOpenWithOption` 枚举，包含 `.special` 和 `.browser` 两种 case
- [x] 1.2 为 `BookmarkOpenWithOption` 添加 `displayName` 计算属性
- [x] 1.3 为 `BookmarkOpenWithOption` 添加 `icon` 计算属性
- [x] 1.4 为 `BookmarkOpenWithOption` 实现与 `BookmarkOpenWith` 的转换方法

## 2. 更新 BookmarkSettings 数据验证

- [x] 2.1 在 `BookmarkSettings.load()` 中添加浏览器安装状态验证逻辑
- [x] 2.2 实现当选中的浏览器未安装时自动回退到 `defaultBrowser` 的逻辑
- [x] 2.3 添加解码失败时的默认值处理

## 3. 更新 BookmarkService 打开逻辑

- [x] 3.1 在 `BookmarkService.open(_:)` 方法中添加对所有 `BookmarkSource` 浏览器的支持
- [x] 3.2 更新 `openWithBrowser(url:source:)` 方法以支持所有浏览器的 Bundle ID
- [x] 3.3 确保浏览器未安装时正确回退到默认浏览器

## 4. 更新 UI 层动态选项生成

- [x] 4.1 在 `BookmarkSearchSettingsView` 中创建 `availableOpenWithOptions` 计算属性
- [x] 4.2 修改"打开浏览器" Picker 使用动态生成的选项列表
- [x] 4.3 更新 Picker 的 `selection` 绑定以支持新的选项类型
- [x] 4.4 确保 Picker 正确显示浏览器图标和名称

## 5. 处理设置保存和加载

- [x] 5.1 实现 `BookmarkOpenWithOption` 到 `BookmarkOpenWith` 的序列化逻辑
- [x] 5.2 实现 `BookmarkOpenWith` 到 `BookmarkOpenWithOption` 的反序列化逻辑
- [x] 5.3 确保 Picker 的 `onChange` 正确保存用户选择

## 6. 测试与验证

- [x] 6.1 测试所有已安装浏览器都出现在"打开浏览器"选项中
- [x] 6.2 测试未安装的浏览器不出现在选项中
- [x] 6.3 测试"书签浏览器"和"默认浏览器"特殊选项正常工作
- [x] 6.4 测试使用每个浏览器打开书签功能
- [x] 6.5 测试现有用户设置升级后保持不变
- [x] 6.6 测试选中的浏览器被卸载后自动回退到默认浏览器
- [x] 6.7 验证项目编译通过
