import SwiftUI

struct PermissionSettingsView: View {
    @ObservedObject var permissionService = PermissionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("系统权限")
                    .fontWeight(.semibold)
                Spacer()

                // Overall status
                if permissionService.allPermissionsGranted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("全部已授权")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            VStack(spacing: 8) {
                PermissionBadge(
                    icon: "hand.raised.fill",
                    title: "辅助功能",
                    description: "快捷键",
                    isGranted: permissionService.isAccessibilityGranted,
                    isRequired: true,
                    action: {
                        if permissionService.isAccessibilityGranted {
                            permissionService.openAccessibilitySettings()
                        } else {
                            permissionService.requestAccessibility()
                        }
                    }
                )

                PermissionBadge(
                    icon: "doc.fill",
                    title: "完全磁盘访问",
                    description: "文档搜索",
                    isGranted: permissionService.isFullDiskAccessGranted,
                    isRequired: false,
                    action: { permissionService.requestFullDiskAccess() }
                )

                PermissionBadge(
                    icon: "rectangle.on.rectangle",
                    title: "屏幕录制",
                    description: "窗口信息",
                    isGranted: permissionService.isScreenRecordingGranted,
                    isRequired: false,
                    action: {
                        if permissionService.isScreenRecordingGranted {
                            permissionService.openScreenRecordingSettings()
                        } else {
                            permissionService.requestScreenRecording()
                        }
                    }
                )
            }

            Text("这些权限仅用于应用功能，不会收集或传输任何个人数据。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            permissionService.checkAllPermissions()
        }
    }
}

struct PermissionBadge: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isRequired: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isGranted ? .green : .orange)
                    .frame(width: 20)

                // Title and description
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        if isRequired && !isGranted {
                            Text("必需")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(3)
                        }
                    }
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                Image(
                    systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .foregroundColor(isGranted ? .green : .orange)
                .font(.system(size: 16))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(isGranted ? "已授权 - 点击打开系统设置" : "点击授权")
    }
}
