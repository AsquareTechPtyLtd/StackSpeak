import SwiftUI

/// Wraps a custom-size system font in `@ScaledMetric` so SF Symbol glyphs at
/// hero sizes (`IconSizeTokens.large` / `.xLarge` / `.hero`) still scale with
/// Dynamic Type. The standard `.font(.system(size:weight:))` call has no
/// `relativeTo:` parameter, so a fixed point size pins the glyph regardless
/// of accessibility size — this modifier closes that gap without rerouting
/// SF Symbols through `.custom()`.
private struct ScaledIconFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// Apply a Dynamic-Type-scaled system font at a custom point size — used
    /// for hero icons that sit above the largeTitle baseline. The `relativeTo`
    /// text style controls how the glyph scales as accessibility size grows.
    func scaledIcon(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .largeTitle
    ) -> some View {
        modifier(ScaledIconFont(size: size, weight: weight, relativeTo: textStyle))
    }
}
