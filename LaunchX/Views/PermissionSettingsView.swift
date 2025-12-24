import SwiftUI

struct PermissionSettingsView: View {
    @ObservedObject var permissionService = PermissionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Permissions Required:")
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(spacing: 12) {
                PermissionBadge(
                    title: "Accessibility",
                    isGranted: permissionService.isAccessibilityGranted,
                    action: {
                        if permissionService.isAccessibilityGranted {
                            permissionService.openAccessibilitySettings()
                        } else {
                            permissionService.requestAccessibility()
                        }
                    }
                )

                PermissionBadge(
                    title: "Screen Recording",
                    isGranted: permissionService.isScreenRecordingGranted,
                    action: {
                        if permissionService.isScreenRecordingGranted {
                            permissionService.openScreenRecordingSettings()
                        } else {
                            permissionService.requestScreenRecording()
                        }
                    }
                )

                PermissionBadge(
                    title: "Full Disk Access",
                    isGranted: permissionService.isFullDiskAccessGranted,
                    action: { permissionService.requestFullDiskAccess() }
                )
            }

            Text(
                "LaunchX requires these permissions to function correctly. The app does not collect or track any personal data via these permissions."
            )
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
    let title: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(
                    systemName: isGranted
                        ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundColor(isGranted ? .green : .orange)
                .font(.system(size: 14))

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help(isGranted ? "Permission granted" : "Click to open System Settings")
    }
}
