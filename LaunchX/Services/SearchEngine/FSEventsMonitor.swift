import CoreServices
import Foundation

/// Monitors file system changes using FSEvents API
/// Provides real-time updates for incremental index maintenance
final class FSEventsMonitor {

    /// Event types for file system changes
    enum EventType {
        case created
        case modified
        case deleted
        case renamed
    }

    /// File system event
    struct FSEvent {
        let path: String
        let type: EventType
        let isDirectory: Bool
    }

    /// Callback for file system events
    typealias EventCallback = ([FSEvent]) -> Void

    private var streamRef: FSEventStreamRef?
    private var callback: EventCallback?
    private var monitoredPaths: [String] = []
    private let eventQueue = DispatchQueue(label: "com.launchx.fsevents", qos: .utility)

    // Debounce events to avoid flooding
    private var pendingEvents: [String: EventType] = [:]
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Start monitoring specified paths
    /// - Parameters:
    ///   - paths: Directories to monitor
    ///   - callback: Called when file system events occur
    func start(paths: [String], callback: @escaping EventCallback) {
        stop()  // Stop any existing monitoring

        self.callback = callback
        self.monitoredPaths = paths

        let pathsToWatch = paths as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )

        streamRef = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,  // Latency in seconds
            flags
        )

        guard let stream = streamRef else {
            print("FSEventsMonitor: Failed to create event stream")
            return
        }

        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)

        print("FSEventsMonitor: Started monitoring \(paths.count) paths")
    }

    /// Stop monitoring
    func stop() {
        guard let stream = streamRef else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil

        debounceWorkItem?.cancel()
        pendingEvents.removeAll()

        print("FSEventsMonitor: Stopped monitoring")
    }

    /// Check if currently monitoring
    var isMonitoring: Bool {
        return streamRef != nil
    }

    // MARK: - Event Processing

    fileprivate func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        for (index, path) in paths.enumerated() {
            let flag = flags[index]

            // Determine event type
            let eventType: EventType

            if flag & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                eventType = .deleted
            } else if flag & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                // Renamed could be move in or move out
                if FileManager.default.fileExists(atPath: path) {
                    eventType = .created
                } else {
                    eventType = .deleted
                }
            } else if flag & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                eventType = .created
            } else if flag & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
                eventType = .modified
            } else {
                continue  // Skip other events
            }

            // Skip hidden files and system directories
            let fileName = (path as NSString).lastPathComponent
            if fileName.hasPrefix(".") { continue }
            if path.contains("/.Trash/") { continue }
            if path.contains("/Library/Caches/") { continue }

            pendingEvents[path] = eventType
        }

        // Debounce: wait for events to settle
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.flushPendingEvents()
        }

        eventQueue.asyncAfter(deadline: .now() + debounceInterval, execute: debounceWorkItem!)
    }

    private func flushPendingEvents() {
        guard !pendingEvents.isEmpty else { return }

        let events = pendingEvents.map { (path, type) -> FSEvent in
            let isDir =
                FileManager.default.fileExists(atPath: path)
                && (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true
            return FSEvent(path: path, type: type, isDirectory: isDir)
        }

        pendingEvents.removeAll()

        // Call callback on main thread
        DispatchQueue.main.async { [weak self] in
            self?.callback?(events)
        }
    }
}

// MARK: - FSEvents Callback

private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }

    let monitor = Unmanaged<FSEventsMonitor>.fromOpaque(info).takeUnretainedValue()

    // Convert paths
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

    // Convert flags
    let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

    monitor.handleEvents(paths: paths, flags: flags)
}
