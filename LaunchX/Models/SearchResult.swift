import AppKit
import Foundation

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage
    let isDirectory: Bool

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
