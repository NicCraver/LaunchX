import Carbon
import SwiftUI

// MARK: - AI 翻译设置视图

struct AITranslateSettingsView: View {
    @State private var settings = AITranslateSettings.load()
    @State private var showSelectionHotKeyPopover = false
    @State private var showInputHotKeyPopover = false
    @State private var showAddModelSheet = false
    @State private var showAddServiceSheet = false
    @State private var editingModel: AIModelConfig?
    @State private var editingService: TranslateServiceConfig?

    private let labelWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 标题行
                HStack(spacing: SettingsHeaderStyle.iconTitleSpacing) {
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: SettingsHeaderStyle.iconSize))
                        .foregroundColor(.indigo)
                        .frame(width: SettingsHeaderStyle.iconFrameSize, height: SettingsHeaderStyle.iconFrameSize)
                    Text("AI 翻译")
                        .font(SettingsHeaderStyle.titleFont)
                        .fontWeight(SettingsHeaderStyle.titleFontWeight)
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: settings.isEnabled) { _, _ in
                            settings.save()
                        }
                }
                .padding(.horizontal, SettingsHeaderStyle.horizontalPadding)
                .padding(.top, SettingsHeaderStyle.topPadding)
                .padding(.bottom, SettingsHeaderStyle.bottomPadding)

                Divider()

                // 快捷键设置
                Group {
                    HStack {
                        Text("选词翻译快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        TranslateHotKeyButton(
                            keyCode: $settings.selectionHotKeyCode,
                            modifiers: $settings.selectionHotKeyModifiers,
                            showPopover: $showSelectionHotKeyPopover,
                            hotKeyType: "translateSelection"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerTranslateSelectionHotKey(
                                keyCode: settings.selectionHotKeyCode,
                                modifiers: settings.selectionHotKeyModifiers
                            )
                        }
                        Spacer()
                    }

                    HStack {
                        Text("输入翻译快捷键:")
                            .frame(width: labelWidth, alignment: .trailing)
                        TranslateHotKeyButton(
                            keyCode: $settings.inputHotKeyCode,
                            modifiers: $settings.inputHotKeyModifiers,
                            showPopover: $showInputHotKeyPopover,
                            hotKeyType: "translateInput"
                        ) {
                            settings.save()
                            HotKeyService.shared.registerTranslateInputHotKey(
                                keyCode: settings.inputHotKeyCode,
                                modifiers: settings.inputHotKeyModifiers
                            )
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .padding(.top, 16)

                // AI 模型配置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("AI 模型配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showAddModelSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    if settings.modelConfigs.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "cpu")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("暂无模型配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("添加模型") {
                                    showAddModelSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        ForEach(settings.modelConfigs) { config in
                            ModelConfigRow(
                                config: config,
                                isDefault: config.isDefault,
                                onEdit: { editingModel = config },
                                onDelete: { deleteModel(config) },
                                onSetDefault: { setDefaultModel(config) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .padding(.top, 16)

                // 翻译服务配置
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("翻译服务配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showAddServiceSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(settings.serviceConfigs) { config in
                        ServiceConfigRow(
                            config: config,
                            onEdit: { editingService = config },
                            onToggle: { toggleService(config) }
                        )
                    }
                }
                .padding(20)

                Spacer()
            }
        }
        .sheet(isPresented: $showAddModelSheet) {
            ModelConfigEditorSheet(mode: .add) { newConfig in
                addModel(newConfig)
            }
        }
        .sheet(item: $editingModel) { config in
            ModelConfigEditorSheet(mode: .edit(config)) { updatedConfig in
                updateModel(updatedConfig)
            }
        }
        .sheet(isPresented: $showAddServiceSheet) {
            ServiceConfigEditorSheet(mode: .add) { newConfig in
                addService(newConfig)
            }
        }
        .sheet(item: $editingService) { config in
            ServiceConfigEditorSheet(mode: .edit(config)) { updatedConfig in
                updateService(updatedConfig)
            }
        }
    }

    // MARK: - 模型管理

    private func addModel(_ config: AIModelConfig) {
        var newConfig = config
        if settings.modelConfigs.isEmpty {
            newConfig = AIModelConfig(
                id: config.id,
                name: config.name,
                provider: config.provider,
                apiKey: config.apiKey,
                model: config.model,
                baseURL: config.baseURL,
                isDefault: true
            )
        }
        settings.modelConfigs.append(newConfig)
        settings.save()
    }

    private func updateModel(_ config: AIModelConfig) {
        if let index = settings.modelConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.modelConfigs[index] = config
            settings.save()
        }
    }

    private func deleteModel(_ config: AIModelConfig) {
        settings.modelConfigs.removeAll { $0.id == config.id }
        // 如果删除的是默认模型，设置第一个为默认
        if config.isDefault && !settings.modelConfigs.isEmpty {
            settings.modelConfigs[0] = AIModelConfig(
                id: settings.modelConfigs[0].id,
                name: settings.modelConfigs[0].name,
                provider: settings.modelConfigs[0].provider,
                apiKey: settings.modelConfigs[0].apiKey,
                model: settings.modelConfigs[0].model,
                baseURL: settings.modelConfigs[0].baseURL,
                isDefault: true
            )
        }
        settings.save()
    }

    private func setDefaultModel(_ config: AIModelConfig) {
        for i in 0..<settings.modelConfigs.count {
            let isDefault = settings.modelConfigs[i].id == config.id
            settings.modelConfigs[i] = AIModelConfig(
                id: settings.modelConfigs[i].id,
                name: settings.modelConfigs[i].name,
                provider: settings.modelConfigs[i].provider,
                apiKey: settings.modelConfigs[i].apiKey,
                model: settings.modelConfigs[i].model,
                baseURL: settings.modelConfigs[i].baseURL,
                isDefault: isDefault
            )
        }
        settings.save()
    }

    // MARK: - 服务管理

    private func addService(_ config: TranslateServiceConfig) {
        settings.serviceConfigs.append(config)
        settings.save()
    }

    private func updateService(_ config: TranslateServiceConfig) {
        if let index = settings.serviceConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.serviceConfigs[index] = config
            settings.save()
        }
    }

    private func toggleService(_ config: TranslateServiceConfig) {
        if let index = settings.serviceConfigs.firstIndex(where: { $0.id == config.id }) {
            settings.serviceConfigs[index] = TranslateServiceConfig(
                id: config.id,
                name: config.name,
                serviceType: config.serviceType,
                systemPrompt: config.systemPrompt,
                userPromptTemplate: config.userPromptTemplate,
                modelConfigId: config.modelConfigId,
                isEnabled: !config.isEnabled
            )
            settings.save()
        }
    }
}

