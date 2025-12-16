import AppKit
import Combine
import Foundation

class FileSearchService: NSObject {
    private var query = NSMetadataQuery()
    private var cancellables = Set<AnyCancellable>()

    let resultsSubject = PassthroughSubject<[SearchResult], Never>()

    override init() {
        super.init()
        setupQuery()
    }

    private func setupQuery() {
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering, object: query)
            .sink { [weak self] _ in self?.processResults() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: query)
            .sink { [weak self] _ in self?.processResults() }
            .store(in: &cancellables)
    }

    func search(query text: String) {
        query.stop()

        guard !text.isEmpty else {
            resultsSubject.send([])
            return
        }

        // Search user home directory
        query.searchScopes = [NSMetadataQueryUserHomeScope]

        // Predicate: Name contains text, case-insensitive
        let predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, text)
        query.predicate = predicate

        query.start()
    }

    private func processResults() {
        query.disableUpdates()

        var newResults: [SearchResult] = []
        let limit = 20  // Limit results for UI performance

        let resultCount = query.resultCount
        for i in 0..<min(resultCount, limit) {
            guard let item = query.result(at: i) as? NSMetadataItem,
                let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String
            else {
                continue
            }

            let icon = NSWorkspace.shared.icon(forFile: path)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

            let result = SearchResult(
                name: name,
                path: path,
                icon: icon,
                isDirectory: isDir.boolValue
            )
            newResults.append(result)
        }

        query.enableUpdates()
        resultsSubject.send(newResults)
    }
}
