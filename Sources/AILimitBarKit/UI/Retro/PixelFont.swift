import AppKit
import SwiftUI
import CoreText

public enum PixelFont {
    public static let fontName = "Press Start 2P"
    private nonisolated(unsafe) static var registered = false

    public static func registerBundledFont() {
        guard !registered else { return }
        registered = true
        guard let url = Bundle.module.url(forResource: "PressStart2P-Regular",
                                          withExtension: "ttf",
                                          subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    public static func nsFont(size: CGFloat) -> NSFont {
        registerBundledFont()
        return NSFont(name: fontName, size: size)
            ?? NSFont(name: "PressStart2P-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    public static func swiftUI(size: CGFloat) -> Font {
        registerBundledFont()
        return Font.custom(fontName, size: size)
    }

    /// Half a pixel cell (6.25% of size). Press Start 2P packs its 8×8
    /// glyphs tight; all-caps labels need air, in grid-true steps.
    public static func tracking(forSize size: CGFloat) -> CGFloat {
        size / 16
    }
}

public extension View {
    /// Pixel type with its grid-true tracking applied — the one way to set
    /// Press Start 2P in SwiftUI views.
    func pixelType(size: CGFloat) -> some View {
        font(PixelFont.swiftUI(size: size))
            .tracking(PixelFont.tracking(forSize: size))
    }
}
