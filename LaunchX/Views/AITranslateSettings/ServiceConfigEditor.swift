import Carbon
import SwiftUI

// MARK: - 服务配置编辑器

enum ServiceConfigEditorMode {
    case add
    case edit(TranslateServiceConfig)

    var title: String {
        switch self {
        case .add: return "添加翻译服务"
        case .edit: return "编辑翻译服务"
        }
    }
}

struct ServiceConfigEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ServiceConfigEditorMode
    let onSave: (TranslateServiceConfig) -> Void

    @State private var name: String = ""
    @State private var serviceType: TranslateServiceType = .aiTranslate
    @State private var systemPrompt: String = ""
    @State private var userPromptTemplate: String = ""
    @State private var selectedModelId: UUID?
    @State private var showTemplates = false

    private var modelConfigs: [AIModelConfig] {
        AITranslateSettings.load().modelConfigs
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selectedModelId != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(mode.title)
                    .font(.headline)
                Spacer()

                Button("模板") {
                    showTemplates = true
                }
                .buttonStyle(.bordered)

                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例如：AI 翻译", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 服务类型
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务类型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $serviceType) {
                            ForEach(TranslateServiceType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // 使用模型
                    VStack(alignment: .leading, spacing: 6) {
                        Text("使用模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if modelConfigs.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("请先添加 AI 模型配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            Picker("", selection: $selectedModelId) {
                                Text("请选择模型").tag(nil as UUID?)
                                ForEach(modelConfigs) { config in
                                    Text("\(config.name) (\(config.model))").tag(config.id as UUID?)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    // 角色描述
                    VStack(alignment: .leading, spacing: 6) {
                        Text("角色描述（选填）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }

                    // Prompt 模板
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt（选填）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $userPromptTemplate)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        Text("可用变量: {text}, {fromLang}, {toLang}")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("保存") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if case .edit(let config) = mode {
                name = config.name
                serviceType = config.serviceType
                systemPrompt = config.systemPrompt
                userPromptTemplate = config.userPromptTemplate
                selectedModelId = config.modelConfigId
            }
        }
        .popover(isPresented: $showTemplates) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择模板")
                    .font(.headline)
                    .padding(.bottom, 4)

                Button("AI 翻译（默认）") {
                    applyTemplate(.defaultAITranslate)
                }
                .buttonStyle(.plain)

                Button("单词翻译（带音标）") {
                    applyTemplate(.defaultWordTranslate)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func applyTemplate(_ config: TranslateServiceConfig) {
        name = config.name
        serviceType = config.serviceType
        systemPrompt = config.systemPrompt
        userPromptTemplate = config.userPromptTemplate
        showTemplates = false
    }

    private func saveConfig() {
        let config: TranslateServiceConfig
        if case .edit(let existing) = mode {
            config = TranslateServiceConfig(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                serviceType: serviceType,
                systemPrompt: systemPrompt,
                userPromptTemplate: userPromptTemplate,
                modelConfigId: selectedModelId,
                isEnabled: existing.isEnabled
            )
        } else {
            config = TranslateServiceConfig(
                name: name.trimmingCharacters(in: .whitespaces),
                serviceType: serviceType,
                systemPrompt: systemPrompt,
                userPromptTemplate: userPromptTemplate,
                modelConfigId: selectedModelId
            )
        }
        onSave(config)
        dismiss()
    }
}

