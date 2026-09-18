import SwiftUI
import UIKit

/// Dynamic Type for a design drawn in points.
///
/// The rule the views follow:
/// - A size that **is** a text style's size at the default setting (17 → `.body`, 13 → `.footnote`,
///   17 semibold → `.headline`…) uses that style directly: `.font(.footnote.weight(.medium))`.
///   At the default size it renders exactly as the old `.system(size:)`, and it scales natively.
/// - Any other size (14, 18, 24…) uses `.scaledFont(size:weight:)`, which keeps the size at the
///   default setting and scales it like the nearest text style (`Typography.textStyle(forSize:)`).
/// - **Text that wraps** (descriptions, messages, footers) uses `.scaledFont` even when its size is
///   a text style's: a text style carries its own leading (footnote: 18 pt lines for 13 pt text),
///   so a two-line paragraph would grow ~3 pt at the default size and shift the screen below it.
///   Single-line labels are unaffected and take the text style.
/// - The serifs (`quoteSerif`, `quoteSerifItalic`) scale the same way through
///   `Font.custom(_:size:relativeTo:)`.
/// - SF Symbols drawn as standalone controls or badges (toolbar chevrons, the heart, icons inside
///   fixed circles) keep their design size, like the system's own bar buttons; a symbol inside a
///   `Label` scales with its text.
///
/// Layouts that cannot grow without breaking (the full-screen quote, the heatmap, the fixed-height
/// suggestion preview, the widgets) cap the range locally with `.dynamicTypeSize(...)` — never
/// globally.
enum Typography {

    /// Every text style with its point size at the default Dynamic Type setting (`.large`),
    /// smallest first. These are Apple's published values.
    static let defaultSizes: [(style: Font.TextStyle, size: CGFloat)] = [
        (.caption2, 11), (.caption, 12), (.footnote, 13), (.subheadline, 15), (.callout, 16),
        (.body, 17), (.title3, 20), (.title2, 22), (.title, 28), (.largeTitle, 34),
    ]

    /// The text style whose default size is closest to `size` — the curve a custom size should
    /// scale along. Ties go to the smaller style, whose curve grows faster (small text needs it).
    static func textStyle(forSize size: CGFloat) -> Font.TextStyle {
        defaultSizes.min { abs($0.size - size) < abs($1.size - size) }?.style ?? .body
    }

    /// `size` scaled for `dynamicTypeSize` along `style`'s curve. Equal to `size` at `.large`.
    static func scaled(_ size: CGFloat, relativeTo style: Font.TextStyle, at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: UIFont.TextStyle(style)).scaledValue(for: size, compatibleWith: traits)
    }
}

extension Font {
    /// Didot, scaling with Dynamic Type like the text style nearest to `size`.
    static func quoteSerif(size: CGFloat) -> Font {
        .custom("Didot", size: size, relativeTo: Typography.textStyle(forSize: size))
    }

    /// Georgia, scaling with Dynamic Type like the text style nearest to `size`.
    static func quoteSerifItalic(size: CGFloat) -> Font {
        .custom("Georgia", size: size, relativeTo: Typography.textStyle(forSize: size))
    }
}

/// The system font at a design size that has no text style of its own, scaled with Dynamic Type.
private struct ScaledSystemFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let relativeTo: Font.TextStyle

    func body(content: Content) -> some View {
        content.font(.system(
            size: Typography.scaled(size, relativeTo: relativeTo, at: dynamicTypeSize),
            weight: weight,
            design: design
        ))
    }
}

extension View {
    /// `.font(.system(size:weight:design:))` that follows the user's text size. Use a text style
    /// instead when `size` is one (see `Typography`).
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle? = nil
    ) -> some View {
        modifier(ScaledSystemFont(
            size: size,
            weight: weight,
            design: design,
            relativeTo: style ?? Typography.textStyle(forSize: size)
        ))
    }
}

extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .body: self = .body
        case .callout: self = .callout
        case .footnote: self = .footnote
        case .caption: self = .caption1
        case .caption2: self = .caption2
        @unknown default: self = .body
        }
    }
}
