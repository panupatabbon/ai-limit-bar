import SwiftUI

/// Visible keyboard-focus indicator for plain-style buttons: a 1px white
/// rectangle in the flat pixel language (no system glow, no rounding).
public struct PixelFocusRing: ViewModifier {
    @FocusState private var focused: Bool

    public func body(content: Content) -> some View {
        content
            .focused($focused)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    .padding(-3)
                    .opacity(focused ? 1 : 0)
            )
    }
}

public extension View {
    func pixelFocusRing() -> some View { modifier(PixelFocusRing()) }
}
