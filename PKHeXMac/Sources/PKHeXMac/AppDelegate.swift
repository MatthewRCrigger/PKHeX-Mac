import AppKit

/// Adds a "New Window" item to the app's Dock tile right-click menu. SwiftUI's `WindowGroup`
/// doesn't expose a Dock menu hook itself, so this is the standard AppKit escape hatch
/// (`NSApplicationDelegate.applicationDockMenu(_:)`) — `PKHeXMacApp` hands this delegate the same
/// `openWindow` action its own "New Window" menu command uses, so both paths open an identical
/// fresh, independent save window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `PKHeXMacApp` right after launch, once `openWindow` is available from the environment.
    var openNewWindow: (() -> Void)?

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "New Window", action: #selector(newWindow), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func newWindow() {
        openNewWindow?()
    }
}
