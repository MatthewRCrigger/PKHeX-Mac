import SwiftUI

/// Publishes the frontmost window's `SaveStore` so app-level `.commands` (⌘O, ⌘S) act on whichever
/// window is currently key, now that every window has its own independent `SaveStore` instead of
/// one shared app-wide instance.
private struct FocusedSaveStoreKey: FocusedValueKey {
    typealias Value = SaveStore
}

extension FocusedValues {
    var saveStore: SaveStore? {
        get { self[FocusedSaveStoreKey.self] }
        set { self[FocusedSaveStoreKey.self] = newValue }
    }
}
