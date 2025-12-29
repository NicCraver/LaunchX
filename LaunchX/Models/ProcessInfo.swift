import AppKit
import Foundation

/// 进程信息模型
struct RunningProcessInfo: Identifiable {
    let id: Int32  // PID
    let name: String
    let icon: NSImage?
    let cpuUsage: Double  // CPU 使用率 (0-100)
    let memoryUsage: UInt64  // 内存使用量 (bytes)
    let port: Int?  // 监听端口（仅端口进程有）
    let isApp: Bool  // 是否为应用程序

    /// 格式化的内存显示
    var formattedMemory: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(memoryUsage))
    }

    /// 格式化的 CPU 显示
    var formattedCPU: String {
        return String(format: "%.1f%%", cpuUsage)
    }
}

/// 进程管理服务
class ProcessManager {
    static let shared = ProcessManager()

    private init() {}

    // MARK: - 获取已打开的应用

    /// 获取所有正在运行的应用程序
    func getRunningApps() -> [RunningProcessInfo] {
        var apps: [RunningProcessInfo] = []
        var seenBundleIds = Set<String>()  // 用于去重
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            // 过滤掉没有用户界面的应用
            guard app.activationPolicy == .regular,
                let name = app.localizedName,
                !name.isEmpty
            else { continue }

            // 按 bundleIdentifier 去重
            if let bundleId = app.bundleIdentifier {
                if seenBundleIds.contains(bundleId) {
                    continue
                }
                seenBundleIds.insert(bundleId)
            }

            let pid = app.processIdentifier
            let (cpu, memory) = getProcessStats(pid: pid)

            let processInfo = RunningProcessInfo(
                id: pid,
                name: name,
                icon: app.icon,
                cpuUsage: cpu,
                memoryUsage: memory,
                port: nil,
                isApp: true
            )
            apps.append(processInfo)
        }

        // 按内存使用量排序
        return apps.sorted { $0.memoryUsage > $1.memoryUsage }
    }

    // MARK: - 获取监听端口的进程

    /// 获取所有监听端口的进程
    func getListeningPortProcesses() -> [RunningProcessInfo] {
        var processes: [RunningProcessInfo] = []
        var seenPorts = Set<Int>()

        // 使用 lsof 获取监听端口
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            let lines = output.components(separatedBy: "\n")
            for line in lines.dropFirst() {  // 跳过标题行
                guard !line.isEmpty else { continue }

                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 9 else { continue }

                guard let pid = Int32(parts[1]) else { continue }

                // 解析端口号
                let addressPart = String(parts[8])
                var port: Int?
                if let colonIndex = addressPart.lastIndex(of: ":") {
                    let portStr = String(addressPart[addressPart.index(after: colonIndex)...])
                    port = Int(portStr)
                }

                guard let portNum = port, !seenPorts.contains(portNum) else { continue }
                seenPorts.insert(portNum)

                // 尝试从 NSRunningApplication 获取更友好的名称
                let name: String
                if let app = NSRunningApplication(processIdentifier: pid),
                    let appName = app.localizedName, !appName.isEmpty
                {
                    name = appName
                } else {
                    // 回退到 lsof 的进程名
                    name = String(parts[0])
                }

                let (cpu, memory) = getProcessStats(pid: pid)
                let icon = getProcessIcon(pid: pid)

                let processInfo = RunningProcessInfo(
                    id: pid,
                    name: name,
                    icon: icon,
                    cpuUsage: cpu,
                    memoryUsage: memory,
                    port: portNum,
                    isApp: false
                )
                processes.append(processInfo)
            }
        } catch {
            print("ProcessManager: Failed to get listening ports: \(error)")
        }

        // 按端口号排序
        return processes.sorted { ($0.port ?? 0) < ($1.port ?? 0) }
    }

    // MARK: - 获取进程统计信息

    /// 获取进程的 CPU 和内存使用情况
    private func getProcessStats(pid: Int32) -> (cpu: Double, memory: UInt64) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "%cpu=,rss="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines)
            else {
                return (0, 0)
            }

            let parts = output.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { return (0, 0) }

            let cpu = Double(parts[0]) ?? 0
            let rssKB = UInt64(parts[1]) ?? 0
            let memory = rssKB * 1024  // 转换为 bytes

            return (cpu, memory)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - 获取进程图标

    /// 获取进程图标
    private func getProcessIcon(pid: Int32) -> NSImage? {
        // 尝试从运行的应用中获取图标
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.icon
        }

        // 返回默认的进程图标
        return NSImage(systemSymbolName: "terminal", accessibilityDescription: "Process")
    }

    // MARK: - Kill 进程

    /// 终止进程
    /// - Parameters:
    ///   - pid: 进程 ID
    ///   - force: 是否强制终止 (SIGKILL vs SIGTERM)
    /// - Returns: 是否成功
    func killProcess(pid: Int32, force: Bool = false) -> Bool {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        let result = kill(pid, signal)
        return result == 0
    }

    /// 终止应用程序（优雅退出）
    func terminateApp(pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.terminate()
        }
        return killProcess(pid: pid, force: false)
    }

    /// 强制终止应用程序
    func forceTerminateApp(pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.forceTerminate()
        }
        return killProcess(pid: pid, force: true)
    }
}
