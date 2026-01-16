import Foundation
import TrashCore

let exitCode = TrashCLI.run(arguments: CommandLine.arguments)
exit(Int32(exitCode))
