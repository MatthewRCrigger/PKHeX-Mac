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

extension View {
    /// Sizes a modal sheet's content. macOS sheets size to their content, so they get the fixed
    /// design size. iOS sheets are sized by the system (full width on iPhone, a form sheet on iPad)
    /// and a fixed size overflows them, so there the content fills the sheet instead, inset enough
    /// that the double frame clears the sheet's and screen's rounded corners.
    @ViewBuilder
    func modalFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width, height: height)
        #else
        padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

extension EnvironmentValues {
    /// True on compact-width iOS layouts (iPhone, narrow iPad multitasking), where `ContentView`
    /// swaps the three-column layout for a sidebar drawer and an inspector sheet. Always false on
    /// macOS. Set once by `ContentView`; views below read it to stack what would sit side by side.
    @Entry var isCompactLayout = false
}
