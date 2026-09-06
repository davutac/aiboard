import AppKit
import SwiftUI

// MARK: - TastkoMain
@main
enum TastkoMain {
    // MARK: - Entry Point
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--login-window")
            || Bundle.main.bundleIdentifier == "com.davutcaliskan.Tastko.LoginWindow"
        {
            LoginWindowApplication.run()
            return
        }

        // Root must never enter the normal user app or read user profile files.
        guard getuid() != 0 else { exit(EXIT_FAILURE) }
        if arguments.count == 3, arguments[1] == "--export-login-keyboard" {
            do {
                try LoginWindowKeyboard.export(to: URL(filePath: arguments[2]))
            }
            catch {
                fputs("Cannot export login keyboard: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
            return
        }
        if arguments.count == 3, arguments[1] == "--validate-login-keyboard" {
            do {
                _ = try LoginWindowKeyboard.load(from: URL(filePath: arguments[2]))
            }
            catch {
                fputs("Invalid login keyboard: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
            return
        }
        TastkoApp.main()
    }
}
