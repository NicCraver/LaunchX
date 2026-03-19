import XCTest

@testable import LaunchX

final class IDERecentProjectsServiceTests: XCTestCase {
    func testRunCommandCapturesLargeStdoutWithoutDeadlocking() throws {
        let completed = expectation(description: "command completes")
        var output: String?
        var thrownError: Error?

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                output = try IDERecentProjectsService.runCommand(
                    executablePath: "/usr/bin/python3",
                    arguments: [
                        "-c", "import sys; sys.stdout.write('a' * 100000)",
                    ])
            } catch {
                thrownError = error
            }

            completed.fulfill()
        }

        wait(for: [completed], timeout: 2.0)
        XCTAssertNil(thrownError)
        XCTAssertEqual(output?.count, 100_000)
    }
}
