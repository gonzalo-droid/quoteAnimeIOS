import SwiftUI
import Testing
@testable import quoteAnime

/// Dynamic Type must leave the design untouched at the default text size and make it follow the
/// user's setting everywhere else. `Typography.scaled` is the arithmetic behind `.scaledFont`;
/// the text styles and `Font.custom(_:size:relativeTo:)` are Apple's and are checked in the
/// simulator captures instead.
@Suite("Typography: Dynamic Type")
struct TypographyTests {

    private static let designSizes: [CGFloat] = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 30]

    @Test("en el tamaño por defecto el tamaño de diseño no cambia", arguments: designSizes)
    func defaultSizeIsTheDesignSize(size: CGFloat) {
        let style = Typography.textStyle(forSize: size)
        #expect(Typography.scaled(size, relativeTo: style, at: .large) == size)
    }

    @Test("en tamaños de accesibilidad el texto crece", arguments: designSizes)
    func accessibilitySizesGrow(size: CGFloat) {
        let style = Typography.textStyle(forSize: size)
        #expect(Typography.scaled(size, relativeTo: style, at: .accessibility3) > size)
    }

    @Test("el escalado sigue el orden de los tamaños del sistema", arguments: designSizes)
    func scalingIsMonotonic(size: CGFloat) {
        let style = Typography.textStyle(forSize: size)
        let steps = DynamicTypeSize.allCases.map { Typography.scaled(size, relativeTo: style, at: $0) }
        #expect(steps == steps.sorted())
    }

    @Test("cada tamaño de diseño escala como el estilo de texto más cercano", arguments: [
        (size: CGFloat(9), style: Font.TextStyle.caption2),
        (size: 11, style: .caption2),
        (size: 12, style: .caption),
        (size: 13, style: .footnote),
        (size: 14, style: .footnote),
        (size: 15, style: .subheadline),
        (size: 16, style: .callout),
        (size: 17, style: .body),
        (size: 18, style: .body),
        (size: 20, style: .title3),
        (size: 24, style: .title2),
        (size: 26, style: .title),
        (size: 34, style: .largeTitle),
    ])
    func nearestTextStyle(size: CGFloat, style: Font.TextStyle) {
        #expect(Typography.textStyle(forSize: size) == style)
    }

    @Test("los tamaños por defecto de la tabla son los de UIKit")
    func defaultSizesMatchUIKit() {
        let large = UITraitCollection(preferredContentSizeCategory: .large)
        for entry in Typography.defaultSizes {
            let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle(entry.style), compatibleWith: large)
            #expect(font.pointSize == entry.size, "\(entry.style)")
        }
    }
}
