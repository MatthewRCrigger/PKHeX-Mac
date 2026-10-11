import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#endif

extension PlatformImage {
    /// An image from the app's asset catalog by name, on either platform.
    static func asset(_ name: String) -> PlatformImage? {
        #if os(macOS)
        NSImage(named: name)
        #else
        UIImage(named: name)
        #endif
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension View {
    /// Escape-to-cancel for text fields. macOS only; iOS has no exit command, so this is a no-op there.
    @ViewBuilder
    func onExitCommandIfAvailable(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onExitCommand(perform: action)
        #else
        self
        #endif
    }
}
