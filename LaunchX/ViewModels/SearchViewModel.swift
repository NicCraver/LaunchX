import AppKit
import Combine
import SwiftUI

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [SearchResult] = []
    @Published var selectedIndex = 0

    private let searchService = FileSearchService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce search text changes
        $searchText
            .removeDuplicates()
            .sink { [weak self] text in
                self?.searchService.search(query: text)
            }
            .store(in: &cancellables)

        // Observe results updates from the service
        searchService.resultsSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] newResults in
                self?.results = newResults
                self?.selectedIndex = 0  // Reset selection when results change
            }
            .store(in: &cancellables)
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

        // Hide the panel after opening
        PanelManager.shared.togglePanel()

        // Optional: clear search text
        searchText = ""
    }
}
