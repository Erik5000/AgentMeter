import AppKit
import SwiftUI

enum MenuBarChrome {
    static var quitTitle: String {
        "Quit \(AppIdentity.displayName)"
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}

struct MenuBarQuitButton: View {
    var body: some View {
        Button(MenuBarChrome.quitTitle) {
            MenuBarChrome.quit()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel(MenuBarChrome.quitTitle)
    }
}
