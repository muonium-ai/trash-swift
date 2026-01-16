import AppKit
import Carbon
import Foundation
import Security

public struct TrashCLI {
    private static let versionMajor = 1
    private static let versionMinor = 0
    private static let versionBuild = 0

    public static func run(arguments: [String]) -> Int {
        let argv = arguments
        let basename = (argv.first ?? "trash") as NSString
        if argv.count == 1 {
            printUsage(basename: basename.lastPathComponent)
            return 0
        }

        var argVerbose = false
        var argList = false
        var argEmpty = false
        var argEmptySecurely = false
        var argSkipPrompt = false
        var argUseFinderToTrash = false

        var paths: [String] = []
        var parsingOptions = true

        for arg in argv.dropFirst() {
            if parsingOptions && arg == "--" {
                parsingOptions = false
                continue
            }

            if parsingOptions && arg.hasPrefix("-") && arg.count > 1 {
                if arg == "-" {
                    paths.append(arg)
                    continue
                }

                for ch in arg.dropFirst() {
                    switch ch {
                    case "v": argVerbose = true
                    case "l": argList = true
                    case "e": argEmpty = true
                    case "s": argEmptySecurely = true
                    case "y": argSkipPrompt = true
                    case "F": argUseFinderToTrash = true
                    case "d", "f", "i", "r", "P", "R", "W":
                        break
                    default:
                        printUsage(basename: basename.lastPathComponent)
                        return 1
                    }
                }
            } else {
                paths.append(arg)
            }
        }

        if argList {
            do {
                let items = try listTrashContents()
                for item in items {
                    printOut("\(item)\n")
                }
                if argVerbose {
                    let total = diskUsageForTrashItems(items)
                    let formattedBytes = formatNumber(total)
                    printOut("\nCalculating total disk usage of files in trash...\n")
                    printOut("Total: \(stringFromFileSize(total)) (\(formattedBytes) bytes)\n")
                }
                return 0
            } catch {
                printErr("trash: \(error.localizedDescription)\n")
                return 1
            }
        }

        if argEmpty || argEmptySecurely {
            do {
                let items = try listTrashContents()
                if items.isEmpty {
                    printOut("The trash is already empty.\n")
                    return 0
                }
                if !argSkipPrompt {
                    let plural = items.count > 1
                    let suffix = plural ? "s" : ""
                    let these = plural ? "these" : "this"
                    let are = plural ? "are" : "is"
                    let secureStr = argEmptySecurely ? " (and securely)" : ""
                    printOut("There \(are) currently \(items.count) item\(suffix) in the trash.\n")
                    printOut("Are you sure you want to permanently\(secureStr) delete \(these) item\(suffix)?\n")
                    printOut("(y = permanently empty the trash, l = list items in trash, n = don't empty)\n")

                    while true {
                        let input = promptForChar(acceptable: "ylN")
                        if input == "l" {
                            for item in items { printOut("\(item)\n") }
                        } else if input != "y" {
                            return 1
                        } else {
                            break
                        }
                    }
                }

                if argEmptySecurely {
                    printOut("(secure empty trash will take a long while so please be patient...)\n")
                }

                try emptyTrash(securely: argEmptySecurely)
                return 0
            } catch {
                printErr("trash: \(error.localizedDescription)\n")
                return 1
            }
        }

        checkForRoot()

        var pathsForFinder: [String] = []
        var exitValue = 0

        for rawPath in paths {
            let expandedPath = (rawPath as NSString).expandingTildeInPath
            if expandedPath.isEmpty {
                printErr("trash: \(rawPath): invalid path\n")
                continue
            }

            if !fileExistsNoFollowSymlink(expandedPath) {
                printErr("trash: \(rawPath): path does not exist\n")
                exitValue = 1
                continue
            }

            if argUseFinderToTrash {
                pathsForFinder.append(expandedPath)
                continue
            }

            do {
                try moveFileToTrashStandard(expandedPath)
                if argVerbose { printOut("\(expandedPath)\n") }
            } catch TrashError.permissionDenied {
                pathsForFinder.append(expandedPath)
            } catch {
                exitValue = 1
                printErr("trash: \(rawPath): can not move to trash (\(error.localizedDescription))\n")
            }
        }

        if !pathsForFinder.isEmpty {
            let bringFinderToFront = !argUseFinderToTrash
            let status = askFinderToMoveFilesToTrash(pathsForFinder, bringFinderToFront: bringFinderToFront)
            if status != noErr {
                exitValue = 1
                if status == kHGNotAllFilesTrashedError {
                    printErr("trash: some files were not moved to trash (authentication cancelled?)\n")
                } else {
                    printErr("trash: error \(status)\n")
                }
            } else if argVerbose {
                for path in pathsForFinder { printOut("\(path)\n") }
            }
        }

        return exitValue
    }

    private static func versionNumber() -> String {
        "\(versionMajor).\(versionMinor).\(versionBuild)"
    }

    private static func printUsage(basename: String) {
        printOut("usage: \(basename) [-vlesyF] <file> [<file> ...]\n")
        printOut("\n")
        printOut("  Move files/folders to the trash.\n")
        printOut("\n")
        printOut("  Options to use with <file>:\n")
        printOut("\n")
        printOut("  -v  Be verbose (show files as they are trashed, or if\n")
        printOut("      used with the -l option, show additional information\n")
        printOut("      about the trash contents)\n")
        printOut("  -F  Ask Finder to move the files to the trash, instead of\n")
        printOut("      using the system API.\n")
        printOut("\n")
        printOut("  Stand-alone options (to use without <file>):\n")
        printOut("\n")
        printOut("  -l  List items currently in the trash (add the -v option\n")
        printOut("      to see additional information)\n")
        printOut("  -e  Empty the trash (asks for confirmation)\n")
        printOut("  -s  Securely empty the trash (asks for confirmation)\n")
        printOut("  -y  Skips the confirmation prompt for -e and -s.\n")
        printOut("      CAUTION: Deletes permanently instantly.\n")
        printOut("\n")
        printOut("  Options supported by `rm` are silently accepted.\n")
        printOut("\n")
        printOut("Version \(versionNumber())\n")
        printOut("Copyright (c) 2010–2018 Ali Rantakari, http://hasseg.org/trash\n")
        printOut("Copyright (c) 2026 Senthil Nayagam\n")
        printOut("\n")
    }
}

private enum TrashError: Error, LocalizedError {
    case permissionDenied
    case osStatus(OSStatus)
    case appleScriptError(String)
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "permission denied"
        case .osStatus(let status):
            return osStatusToErrorString(status)
        case .appleScriptError(let message):
            return message
        case .invalidPath:
            return "invalid path"
        }
    }
}

private let kHGAppleScriptError: OSStatus = 9999
private let kHGNotAllFilesTrashedError: OSStatus = 9998

private func printOut(_ string: String) {
    if let data = string.data(using: .utf8) {
        FileHandle.standardOutput.write(data)
    }
}

private func printErr(_ string: String) {
    if let data = string.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

private func promptForChar(acceptable: String) -> Character {
    let lower = acceptable.lowercased()
    while true {
        printOut("[")
        for (idx, ch) in acceptable.enumerated() {
            printOut(String(ch))
            if idx < acceptable.count - 1 { printOut("/") }
        }
        printOut("]: ")

        guard let line = readLine(), let first = line.lowercased().first else {
            continue
        }
        if lower.contains(first) {
            return first
        }
    }
}

private func checkForRoot() {
    if getuid() != 0 { return }
    printOut("You seem to be running as root. Any files trashed\n")
    printOut("as root will be moved to root's trash folder instead\n")
    printOut("of your trash folder. Are you sure you want to continue?\n")
    let input = promptForChar(acceptable: "yN")
    if input != "y" {
        exit(1)
    }
}

func fileExistsNoFollowSymlink(_ path: String) -> Bool {
    var statBuf = stat()
    return lstat(path, &statBuf) == 0
}

func getAbsolutePath(_ filePath: String) -> String {
    let nsPath = filePath as NSString
    let parent = nsPath.deletingLastPathComponent
    let name = nsPath.lastPathComponent
    let cwd = FileManager.default.currentDirectoryPath
    let parentAbs: String

    if filePath.hasPrefix("/") {
        parentAbs = (parent as NSString).standardizingPath
    } else {
        parentAbs = ((cwd as NSString).appendingPathComponent(parent) as NSString).standardizingPath
    }

    return (parentAbs as NSString).appendingPathComponent(name)
}

private func moveFileToTrashStandard(_ path: String) throws {
    let url = URL(fileURLWithPath: path)
    do {
        _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    } catch let error as NSError {
        if error.domain == NSCocoaErrorDomain {
            if error.code == NSFileWriteNoPermissionError || error.code == NSFileWriteNoPermissionError {
                throw TrashError.permissionDenied
            }
        }
        if error.domain == NSPOSIXErrorDomain {
            if error.code == EPERM || error.code == EACCES {
                throw TrashError.permissionDenied
            }
        }
        throw error
    }
}

private func getFinderPID() -> pid_t {
    for app in NSWorkspace.shared.runningApplications {
        if app.bundleIdentifier == "com.apple.finder" {
            return app.processIdentifier
        }
    }
    return -1
}

private func activateFinder() {
    for app in NSWorkspace.shared.runningApplications {
        if app.bundleIdentifier == "com.apple.finder" {
            _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
    }
    let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: finderURL, configuration: configuration, completionHandler: nil)
}

private func askFinderToMoveFilesToTrash(_ filePaths: [String], bringFinderToFront: Bool) -> OSStatus {
    let urlList = NSAppleEventDescriptor.list()
    var index = 1
    for path in filePaths {
        let absPath = getAbsolutePath(path)
        let url = URL(fileURLWithPath: absPath)
        let urlString = url.absoluteString
        let data = urlString.data(using: .utf8) ?? Data()
        if let descr = NSAppleEventDescriptor(descriptorType: fourCharCode("furl"), data: data) {
            urlList.insert(descr, at: index)
        }
        index += 1
    }

    var finderPID = getFinderPID()
    if finderPID == -1 {
        activateFinder()
        finderPID = getFinderPID()
    }

    var pid = finderPID
    let target = NSAppleEventDescriptor(descriptorType: typeKernelProcessID, bytes: &pid, length: MemoryLayout.size(ofValue: pid))
    let event = NSAppleEventDescriptor(
        eventClass: fourCharCode("core"),
        eventID: fourCharCode("delo"),
        targetDescriptor: target,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setParam(urlList, forKeyword: keyDirectObject)

    if bringFinderToFront {
        activateFinder()
    }

    var replyEvent = AppleEvent()
    let sendErr = AESendMessage(event.aeDesc, &replyEvent, AESendMode(kAEWaitReply), kAEDefaultTimeout)
    if sendErr != noErr { return sendErr }

    var replyAEDesc = AEDesc()
    let getReplyErr = AEGetParamDesc(&replyEvent, keyDirectObject, typeWildCard, &replyAEDesc)
    if getReplyErr != noErr { return OSStatus(getReplyErr) }

    let replyDesc = NSAppleEventDescriptor(aeDescNoCopy: &replyAEDesc)
    if replyDesc.numberOfItems == 0 {
        return kHGNotAllFilesTrashedError
    }
    if filePaths.count > 1 && (replyDesc.descriptorType != typeAEList || replyDesc.numberOfItems != filePaths.count) {
        return kHGNotAllFilesTrashedError
    }

    return noErr
}

private func listTrashContents() throws -> [String] {
    let script = "tell application \"Finder\" to get POSIX path of every item of trash"
    let result = try runAppleScript(script)
    guard let result = result else { return [] }

    var paths: [String] = []
    if result.descriptorType == typeAEList {
        for idx in 1...result.numberOfItems {
            if let item = result.atIndex(idx)?.stringValue {
                paths.append(item)
            }
        }
    } else if let single = result.stringValue {
        paths.append(single)
    }

    return paths
}

private func emptyTrash(securely: Bool) throws {
    let script: String
    if securely {
        script = "tell application \"Finder\" to empty trash with security"
    } else {
        script = "tell application \"Finder\" to empty trash"
    }
    _ = try runAppleScript(script)
}

private func runAppleScript(_ source: String) throws -> NSAppleEventDescriptor? {
    guard let script = NSAppleScript(source: source) else {
        throw TrashError.appleScriptError("failed to create script")
    }
    var errorInfo: NSDictionary?
    let result = script.executeAndReturnError(&errorInfo)
    if let errorInfo = errorInfo, errorInfo.count > 0 {
        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
        throw TrashError.appleScriptError(message)
    }
    return result
}

private func diskUsageForTrashItems(_ items: [String]) -> Int64 {
    var total: Int64 = 0
    for path in items {
        let url = URL(fileURLWithPath: path)
        total += physicalSize(url: url)
    }
    return total
}

private func physicalSize(url: URL) -> Int64 {
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
        if isDir.boolValue {
            return sizeOfFolder(url: url, physical: true)
        } else {
            return fileSize(url: url, physical: true)
        }
    }
    return 0
}

private func fileSize(url: URL, physical: Bool) -> Int64 {
    do {
        let keys: Set<URLResourceKey> = [
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .totalFileSizeKey
        ]
        let values = try url.resourceValues(forKeys: keys)
        if physical {
            return Int64(values.fileAllocatedSize ?? values.totalFileAllocatedSize ?? values.fileSize ?? values.totalFileSize ?? 0)
        } else {
            return Int64(values.fileSize ?? values.totalFileSize ?? values.fileAllocatedSize ?? values.totalFileAllocatedSize ?? 0)
        }
    } catch {
        return 0
    }
}

private func sizeOfFolder(url: URL, physical: Bool) -> Int64 {
    let keys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
        .totalFileSizeKey
    ]

    guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: nil) else {
        return 0
    }

    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
        total += fileSize(url: fileURL, physical: physical)
    }
    return total
}

private func stringFromFileSize(_ size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}

private func formatNumber(_ value: Int64) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func osStatusToErrorString(_ status: OSStatus) -> String {
    if let message = SecCopyErrorMessageString(status, nil) as String? {
        return message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "OSStatus \(status)"
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8 {
        result = (result << 8) + OSType(char)
    }
    return result
}
