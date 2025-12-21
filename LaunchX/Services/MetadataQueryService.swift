import Cocoa
import Combine
import Foundation

/// A high-performance service that builds and maintains an in-memory index
/// of files using the high-level NSMetadataQuery API.
///
/// Workflow:
/// 1. Uses NSMetadataQuery to fetch metadata for configured scopes efficiently.
/// 2. Extracts metadata on the main thread (NSMetadataItem is not thread-safe).
/// 3. Offloads heavy processing (Pinyin generation, filtering) to a background queue.
/// 4. Splits index into Apps and Files for prioritized searching.
/// 5. Provides async search with strict result limits.
class MetadataQueryService: ObservableObject {
    static let shared = MetadataQueryService()

    @Published var isIndexing: Bool = false
    @Published var indexedItemCount: Int = 0

    // Split index for optimization
    private var appsIndex: [IndexedItem] = []
    private var filesIndex: [IndexedItem] = []

    // Processing queue for heavy lifting (Pinyin calculation, Search filtering)
    private let processingQueue = DispatchQueue(
        label: "com.launchx.metadata.processing", qos: .userInitiated)

    private var query: NSMetadataQuery?
    private var searchConfig: SearchConfig = SearchConfig()

    // Cancellation token for search requests
    private var currentSearchWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - Public API

    /// Starts or restarts the indexing process based on the provided configuration.
    func startIndexing(with config: SearchConfig) {
        // Ensure main thread for NSMetadataQuery setup
        DispatchQueue.main.async {
            self.stopIndexing()

            self.searchConfig = config
            self.isIndexing = true

            let query = NSMetadataQuery()
            self.query = query

            // Set Search Scopes
            query.searchScopes = config.searchScopes

            // Predicate
            // Equivalent to: kMDItemContentTypeTree == "public.item" && kMDItemContentType != "com.apple.systempreference.prefpane"
            let predicate = NSPredicate(
                format:
                    "%K == 'public.item' AND %K != 'com.apple.systempreference.prefpane'",
                NSMetadataItemContentTypeTreeKey,
                NSMetadataItemContentTypeKey
            )
            query.predicate = predicate

            // Observers
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.queryDidFinishGathering(_:)),
                name: .NSMetadataQueryDidFinishGathering,
                object: query
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.queryDidUpdate(_:)),
                name: .NSMetadataQueryDidUpdate,
                object: query
            )

            print(
                "MetadataQueryService: Starting NSMetadataQuery with scopes: \(config.searchScopes)"
            )

            // Start the query on the Main RunLoop
            if !query.start() {
                print("MetadataQueryService: Failed to start NSMetadataQuery")
                self.isIndexing = false
            }
        }
    }

    func stopIndexing() {
        if let query = query {
            query.stop()
            NotificationCenter.default.removeObserver(
                self, name: .NSMetadataQueryDidFinishGathering, object: query)
            NotificationCenter.default.removeObserver(
                self, name: .NSMetadataQueryDidUpdate, object: query)
            self.query = nil
            self.isIndexing = false
        }
    }

    /// Async search with prioritization and limiting.
    /// - Parameters:
    ///   - text: The search query.
    ///   - completion: Callback with results (Apps first, then Files).
    func search(text: String, completion: @escaping ([IndexedItem]) -> Void) {
        // Cancel previous pending search
        currentSearchWorkItem?.cancel()

        guard !text.isEmpty else {
            completion([])
            return
        }

        // Capture snapshot of indices on Main Thread (thread-safe COW)
        let appsSnapshot = self.appsIndex
        let filesSnapshot = self.filesIndex

        // Create work item
        let workItem = DispatchWorkItem {
            // Check cancellation
            if self.currentSearchWorkItem?.isCancelled ?? true { return }

            // 1. Search Apps (Top Priority)
            let matchedApps = appsSnapshot.filter { $0.searchableName.matches(text) }

            // Sort Apps: Exact > Prefix > Contains > Usage
            let sortedApps = matchedApps.sorted { lhs, rhs in
                // Heuristic sorting
                let lName = lhs.name.lowercased()
                let rName = rhs.name.lowercased()
                let q = text.lowercased()

                if lName == q { return true }
                if rName == q { return false }

                if lName.hasPrefix(q) && !rName.hasPrefix(q) { return true }
                if !lName.hasPrefix(q) && rName.hasPrefix(q) { return false }

                return lhs.lastUsed > rhs.lastUsed
            }
            // Strict limit for apps
            let topApps = Array(sortedApps.prefix(10))

            // Check cancellation
            if self.currentSearchWorkItem?.isCancelled ?? true { return }

            // 2. Search Files (Lower Priority)
            // Optimization: If text is very short (1 char), only search if strictly necessary, or limit scan?
            // For now, we scan all but strictly limit output.
            let matchedFiles = filesSnapshot.filter { $0.searchableName.matches(text) }

            let sortedFiles = matchedFiles.sorted { lhs, rhs in
                return lhs.lastUsed > rhs.lastUsed
            }
            // Strict limit for files
            let topFiles = Array(sortedFiles.prefix(20))

            let combined = topApps + topFiles

            DispatchQueue.main.async {
                // Ensure we are still the relevant search
                if !(self.currentSearchWorkItem?.isCancelled ?? true) {
                    completion(combined)
                }
            }
        }

        self.currentSearchWorkItem = workItem
        processingQueue.async(execute: workItem)
    }

    // MARK: - Query Handlers

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        print("MetadataQueryService: NSMetadataQuery finished gathering")
        processQueryResults(isInitial: true)
        isIndexing = false
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        processQueryResults(isInitial: false)
    }

    private func processQueryResults(isInitial: Bool) {
        guard let query = query else { return }

        // Pause live updates to ensure stability during iteration
        query.disableUpdates()

        // Capture snapshot on Main Thread (fast)
        let results = query.results as? [NSMetadataItem] ?? []

        // Resume updates immediately so we don't block the query for long
        query.enableUpdates()

        // Offload processing to background
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let count = results.count
            var newApps: [IndexedItem] = []
            var newFiles: [IndexedItem] = []

            // Pre-allocate decent capacity
            newApps.reserveCapacity(500)
            newFiles.reserveCapacity(count)

            // Prepare exclusion checks
            let excludedPaths = self.searchConfig.excludedPaths
            let excludedNames = self.searchConfig.excludedNames
            let excludedNamesSet = Set(excludedNames)

            // Iterate results
            for item in results {
                // Get Path
                guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                    continue
                }

                // --- High Performance Filtering ---

                // 1. Path Exclusion (e.g. inside .git or node_modules)
                let pathComponents = path.components(separatedBy: "/")

                // Optimization: Quick check if any excluded name exists in path
                if !excludedNamesSet.isDisjoint(with: pathComponents) { continue }

                // 2. Exact Path Exclusion
                if !excludedPaths.isEmpty {
                    if excludedPaths.contains(where: { path.hasPrefix($0) }) { continue }
                }

                // --- Extraction ---

                // Prioritize Display Name (Localized) for Pinyin
                let name =
                    item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
                    ?? item.value(forAttribute: NSMetadataItemFSNameKey) as? String
                    ?? (path as NSString).lastPathComponent

                let date =
                    item.value(forAttribute: NSMetadataItemContentModificationDateKey) as? Date
                    ?? Date()

                // Check if directory
                let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
                let isDirectory =
                    (contentType == "public.folder" || contentType == "com.apple.mount-point")

                // Check if App
                let isApp = (contentType == "com.apple.application-bundle")

                let cachedItem = IndexedItem(
                    id: UUID(),
                    name: name,
                    path: path,
                    lastUsed: date,
                    isDirectory: isDirectory,
                    searchableName: CachedSearchableString(name)
                )

                if isApp {
                    newApps.append(cachedItem)
                } else {
                    newFiles.append(cachedItem)
                }
            }

            // Sort Apps by name length/usage initially
            newApps.sort { $0.name.count < $1.name.count }

            // Update State on Main Thread
            DispatchQueue.main.async {
                self.appsIndex = newApps
                self.filesIndex = newFiles
                self.indexedItemCount = newApps.count + newFiles.count

                if isInitial {
                    print(
                        "MetadataQueryService: Initial index complete. Apps: \(newApps.count), Files: \(newFiles.count)"
                    )
                }
            }
        }
    }
}

// MARK: - Models

struct IndexedItem: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let lastUsed: Date
    let isDirectory: Bool
    let searchableName: CachedSearchableString

    // Convert to the UI model
    func toSearchResult() -> SearchResult {
        return SearchResult(
            id: id,
            name: name,
            path: path,
            icon: NSWorkspace.shared.icon(forFile: path),
            isDirectory: isDirectory
        )
    }
}
