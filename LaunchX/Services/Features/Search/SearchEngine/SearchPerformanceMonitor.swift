import Foundation

/// Monitors and logs search performance metrics
final class SearchPerformanceMonitor {
    static let shared = SearchPerformanceMonitor()

    private init() {}

    /// Measures the execution time of a search operation
    /// - Parameters:
    ///   - query: The search query string
    ///   - cacheHit: Whether the result was served from cache
    ///   - operation: The search operation to measure
    /// - Returns: The result of the operation
    func measureSearch<T>(query: String, cacheHit: Bool, operation: () -> T) -> T {
        let startTime = DispatchTime.now()
        let result = operation()
        let endTime = DispatchTime.now()

        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000  // Convert to milliseconds

        // Log performance if it's slow or for debugging
        if timeInterval > 100 {
            print(
                "⚠️ Slow Search [\(cacheHit ? "Cache Hit" : "Cache Miss")]: '\(query)' took \(String(format: "%.2f", timeInterval))ms"
            )
        } else {
            // Optional: verbose logging for all searches
            // print("🔍 Search [\(cacheHit ? "Cache Hit" : "Cache Miss")]: '\(query)' took \(String(format: "%.2f", timeInterval))ms")
        }

        return result
    }
}
