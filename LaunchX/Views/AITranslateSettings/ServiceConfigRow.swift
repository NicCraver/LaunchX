import Carbon
import SwiftUI

// MARK: - 服务配置行

struct ServiceConfigRow: View {
    let config: TranslateServiceConfig
    let onEdit: () -> Void
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: config.serviceType.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(config.isEnabled ? .primary : .secondary)
                Text(config.serviceType.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { config.isEnabled },
                    set: { _ in onToggle() }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

