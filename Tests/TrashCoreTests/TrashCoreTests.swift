import XCTest
@testable import TrashCore

final class TrashCoreTests: XCTestCase {
    func testFileExistsNoFollowSymlink() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        let linkURL = tempDir.appendingPathComponent(UUID().uuidString + "_link")
        let danglingURL = tempDir.appendingPathComponent(UUID().uuidString + "_dangling")

        try "hello".data(using: .utf8)?.write(to: fileURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: fileURL)
        try FileManager.default.createSymbolicLink(at: danglingURL, withDestinationURL: tempDir.appendingPathComponent("missing_" + UUID().uuidString))

        XCTAssertTrue(fileExistsNoFollowSymlink(fileURL.path))
        XCTAssertTrue(fileExistsNoFollowSymlink(linkURL.path))
        XCTAssertTrue(fileExistsNoFollowSymlink(danglingURL.path))

        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.removeItem(at: linkURL)
        try FileManager.default.removeItem(at: danglingURL)
    }

    func testGetAbsolutePathWithRelativeInput() {
        let cwd = FileManager.default.currentDirectoryPath
        let relative = "some/dir/file.txt"
        let expected = (cwd as NSString).appendingPathComponent(relative) as NSString
        let expectedStandardized = expected.standardizingPath

        XCTAssertEqual(getAbsolutePath(relative), expectedStandardized)
    }
}
