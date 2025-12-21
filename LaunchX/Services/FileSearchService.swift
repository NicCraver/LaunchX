import AppKit
import Combine
import Foundation

/// Coordinates the high-level search logic, delegating the heavy lifting to MetadataQueryService.
class FileSearchService: ObservableObject {
    // Publishes results to the ViewModel
    let resultsSubject = PassthroughSubject<[SearchResult], Never>()

    private let metadataService = MetadataQueryService.shared

    init() {
        // Start indexing immediately upon initialization with default config.
        // In a real app, you might load this config from UserDefaults.
        let config = SearchConfig()
        metadataService.startIndexing(with: config)
    }

    /// Performs an async search via MetadataQueryService
    func search(query text: String) {
        guard !text.isEmpty else {
            resultsSubject.send([])
            return
        }

        // Delegate to the in-memory index service
        // The search is performed asynchronously on a background queue,
        // but the completion handler is called on the Main Thread.
        metadataService.search(text: text) { [weak self] indexItems in
            // Map internal IndexItems to UI SearchResults
            // This happens on the main thread, which is good for creating NSImages (icons).
            let results = indexItems.map { $0.toSearchResult() }

            self?.resultsSubject.send(results)
        }
    }

    /// Triggers a re-index if settings change (e.g. user adds a new folder)
    func updateConfig(_ config: SearchConfig) {
        metadataService.startIndexing(with: config)
    }
}
