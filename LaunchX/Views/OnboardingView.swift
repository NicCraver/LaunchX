import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissionService = PermissionService.shared
    @State private var showAccessibilityAlert = false

    // Callback to close the window
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                VStack(spacing: 8) {
                    Text("欢迎使用 LaunchX")
                        .font(.system(size: 26, weight: .bold))

                    Text("为了提供最佳体验，LaunchX 需要以下系统权限")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 32)

            // Permissions Section
            VStack(spacing: 12) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: "辅助功能",
                    description: "用于全局快捷键唤起搜索面板",
                    isGranted: permissionService.isAccessibilityGranted,
                    helpText: "如果开关已打开但仍未授权，请先从列表中移除 LaunchX 后重新添加",
                    action: {
                        permissionService.requestAccessibility()
                    }
                )

                PermissionRow(
                    icon: "doc.fill",
                    iconColor: .purple,
                    title: "完全磁盘访问",
                    description: "用于搜索文档和读取 IDE 最近项目",
                    isGranted: permissionService.isFullDiskAccessGranted,
                    helpText: nil,
                    action: {
                        permissionService.requestFullDiskAccess()
                    }
                )

                PermissionRow(
                    icon: "rectangle.on.rectangle",
                    iconColor: .green,
                    title: "屏幕录制",
                    description: "用于获取当前活动窗口信息（可选）",
                    isGranted: permissionService.isScreenRecordingGranted,
                    helpText: nil,
                    action: {
                        permissionService.requestScreenRecording()
                    }
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Footer
            VStack(spacing: 12) {
                // Status message
                if !permissionService.isAccessibilityGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("请先授予辅助功能权限，否则快捷键将无法使用")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已获得必要权限，可以开始使用了")
                            .font(.callout)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Action button
                Button(action: {
                    if permissionService.isAccessibilityGranted {
                        onFinish()
                    } else {
                        showAccessibilityAlert = true
                    }
                }) {
                    HStack {
                        Text(permissionService.isAccessibilityGranted ? "开始使用" : "继续")
                        if permissionService.isAccessibilityGranted {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)

                // Skip hint
                if !permissionService.isAccessibilityGranted {
                    Text("稍后可在系统设置中授予权限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(width: 500, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("需要辅助功能权限", isPresented: $showAccessibilityAlert) {
            Button("去授权") {
                permissionService.requestAccessibility()
            }
            Button("稍后再说", role: .cancel) {
                onFinish()
            }
        } message: {
            Text("没有辅助功能权限，快捷键 ⌥Space 将无法唤起搜索面板。\n\n确定要跳过吗？")
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let helpText: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status / Action
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    Button("授权") {
                        action()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Help text (only show when not granted and helpText exists)
            if !isGranted, let helpText = helpText {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(helpText)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.leading, 52)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isGranted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.1),
                    lineWidth: 1)
        )
    }
}
