# LaunchX
🚀 A modern, pretty, and intelligent macOS launcher.

---

### 安装说明
- 从 releases 下载 LaunchX-vX.X.X-arm64.dmg 或 LaunchX-vX.X.X-arm64.zip
- 打开 DMG 并将 LaunchX 拖入 Applications，或解压 ZIP 后移动到 Applications
- 启动 LaunchX 并授予必要的权限
- 默认使用 `Option + Space` 激活搜索

> 安装出现 「文件已损坏」「移动f到垃圾篓」等问题可以使用 [repair.sh](./repair.sh) 脚本修复 `sh repair.sh`

### 系统要求
- macOS 13.0 或更高版本
- Apple Silicon (M1/M2/M3/M4)
> ⚠️ 本版本仅支持 Apple Silicon Mac，不支持 Intel Mac

### TODO

- [x] high - Implement search performance
- [x] high - fix high cpu percent
- [x] high - 授权逻辑完善，打开文件操作
- [x] low - Add support for custom icons
- [x] low - Remove icon visible in dock
- [ ] low - 顶部栏的icon隐藏设置
- [x] 搜索出的文件默认打开
- [x] 搜索出的文件夹可选打开方式，（根据电脑上已存在的编程app，最好可以支持自定义这样子）
- [x] 对应编程app的最近打开文件的记录

- [x] 别名与快捷键
- [x] 网页直达功能（快捷搜索）
- [ ] 标签搜索功能
- [ ] 配置导出、导入

- [x] 实用工具 - 初步工具集
- [ ] 实用工具 - 计算
- [ ] 实用工具 - 短信验证码,自动读取验证码，可配置验证码模板提取

- [ ] 添加 cmd + k 交互


- [ ] 剪切板
- [ ] snippets
- [ ] AI 模型接入（支持中转）
- [ ] AI 翻译 重点优化提示词 native speaker，美剧，单词

- [x] macos26 毛玻璃效果
