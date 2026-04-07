import SwiftUI

extension Font {
    static func quoteSerif(size: CGFloat) -> Font {
        .custom("Georgia", size: size)
    }

    static func quoteSerifItalic(size: CGFloat) -> Font {
        .custom("Georgia-Italic", size: size)
    }
}
