import AppKit
import EventKit
import Foundation

// MARK: - Reminders Service

final class RemindersService {
    static let shared = RemindersService()

    private let eventStore = EKEventStore()
    private var isAuthorized = false
    private var cachedReminders: [ReminderItem] = []
    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 60  // 1 minute cache

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    @objc private func eventStoreChanged(_ notification: Notification) {
        // Invalidate cache when external changes occur
        refreshCache { _ in
            NotificationCenter.default.post(
                name: Notification.Name("RemindersDataDidChange"), object: nil)
        }
    }

    /// Request access to Reminders
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                self?.isAuthorized = granted
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                self?.isAuthorized = granted
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    /// Check current authorization status
    func checkAuthorization() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
        return isAuthorized
    }

    /// Fetch incomplete reminders
    func fetchIncompleteReminders(
        forceReload: Bool = false, completion: @escaping ([ReminderItem]) -> Void
    ) {
        if !forceReload, let lastFetch = lastFetchTime,
            Date().timeIntervalSince(lastFetch) < cacheInterval
        {
            completion(cachedReminders)
            return
        }

        refreshCache(completion: completion)
    }

    /// Refresh cache from EventKit
    func refreshCache(completion: @escaping ([ReminderItem]) -> Void) {
        guard checkAuthorization() else {
            completion([])
            return
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil)

        eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            guard let self = self else { return }

            guard let ekReminders = ekReminders else {
                DispatchQueue.main.async {
                    self.cachedReminders = []
                    self.lastFetchTime = Date()
                    completion([])
                }
                return
            }

            let items = ekReminders.map { reminder in
                ReminderItem(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title,
                    dueDate: reminder.dueDateComponents?.date,
                    isCompleted: reminder.isCompleted,
                    priority: reminder.priority,
                    listTitle: reminder.calendar.title,
                    listColor: reminder.calendar.color,  // EKCalendar.color is NSColor on macOS
                    notes: reminder.notes,
                    url: reminder.url
                )
            }.sorted { (r1, r2) -> Bool in
                // Sort by priority (1 is highest), then by due date
                if r1.priority != r2.priority {
                    if r1.priority == 0 { return false }
                    if r2.priority == 0 { return true }
                    return r1.priority < r2.priority
                }
                return (r1.dueDate ?? .distantFuture) < (r2.dueDate ?? .distantFuture)
            }

            DispatchQueue.main.async {
                self.cachedReminders = items
                self.lastFetchTime = Date()
                completion(items)
            }
        }
    }

    /// Mark a reminder as completed
    func toggleCompletion(identifier: String, completion: @escaping (Bool) -> Void) {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder
        else {
            completion(false)
            return
        }

        ekReminder.isCompleted = !ekReminder.isCompleted
        if ekReminder.isCompleted {
            ekReminder.completionDate = Date()
        } else {
            ekReminder.completionDate = nil
        }

        do {
            try eventStore.save(ekReminder, commit: true)
            // Update local cache to reflect change immediately
            if let index = cachedReminders.firstIndex(where: { $0.id == identifier }) {
                if ekReminder.isCompleted {
                    cachedReminders.remove(at: index)
                }
            }
            completion(true)
        } catch {
            print("[RemindersService] Error saving reminder: \(error)")
            completion(false)
        }
    }

    /// Open the Reminders app for a specific reminder
    func openInReminders(identifier: String) {
        let urlString = "x-apple-reminder://\(identifier)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Create a quick reminder from query
    func createReminder(title: String, completion: @escaping (Bool) -> Void) {
        guard checkAuthorization() else {
            completion(false)
            return
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)
            // Invalidate cache so it refreshes next time
            lastFetchTime = nil
            completion(true)
        } catch {
            print("[RemindersService] Error creating reminder: \(error)")
            completion(false)
        }
    }
}
