import SwiftUI

// MARK: - Settings Row Component

/// 通用设置行布局组件，用于统一设置界面的标签-内容布局
struct SettingsRow<Content: View>: View {
    let label: String
    let labelWidth: CGFloat
    let alignment: VerticalAlignment
    @ViewBuilder let content: () -> Content

    init(
        label: String,
        labelWidth: CGFloat = 140,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.labelWidth = labelWidth
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 8) {
            Text(label)
                .frame(width: labelWidth, alignment: .trailing)
            content()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SettingsRow(label: "名称:") {
            TextField("输入名称", text: .constant("示例"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }

        SettingsRow(label: "启用:") {
            Toggle("", isOn: .constant(true))
                .toggleStyle(.switch)
        }

        SettingsRow(label: "选项:") {
            Picker("", selection: .constant(0)) {
                Text("选项 1").tag(0)
                Text("选项 2").tag(1)
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }
    .padding()
    .frame(width: 500)
}
