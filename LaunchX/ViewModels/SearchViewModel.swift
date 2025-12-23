import AppKit
import Combine
import SwiftUI

/// High-performance search view model using synchronous in-memory search
/// Inspired by HapiGo's architecture: pre-built index + pure memory query
@MainActor
class SearchViewModel: ObservableObject {
    // Text is updated directly by NSTextField, no SwiftUI overhead
    @Published var searchText = ""

    // Results - updated synchronously on each keystroke
    @Published private(set) var results: [SearchResult] = []
    @Published var selectedIndex = 0

    private let searchEngine = SearchEngine.shared

    init() {
        // SearchEngine handles indexing automatically on init
    }

    // MARK: - Search Logic (Called directly from NSTextField delegate)

    /// Perform search synchronously - this is called on EVERY keystroke
    /// Must be extremely fast (< 1ms) to not block input
    func performSearch(_ query: String) {
        guard !query.isEmpty else {
            results = []
            selectedIndex = 0
            return
        }

        // Direct synchronous search on pre-built index
        let searchResults = searchEngine.searchSync(text: query)

        // Already SearchResult type
        results = searchResults
        selectedIndex = 0
    }

    // MARK: - Navigation Logic

    func moveSelectionDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }

    func moveSelectionUp() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    // MARK: - Execution

    func openSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        let item = results[selectedIndex]

        let url = URL(fileURLWithPath: item.path)
        NSWorkspace.shared.open(url)

        // Clear state BEFORE hiding panel to avoid SwiftUI updates on hidden window
        searchText = ""
        results = []
        selectedIndex = 0

        // Hide the panel after clearing state
        PanelManager.shared.togglePanel()
    }

    /// Reset search state - call this when panel is about to be shown
    func resetState() {
        searchText = ""
        results = []
        selectedIndex = 0
    }
}
