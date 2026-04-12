import UIKit

/// Renders a 1080×1350 share image for a quote using UIGraphicsImageRenderer.
enum ShareImageRenderer {

    // MARK: - Public

    static func fetchAndRender(quote: Quote) async -> UIImage {
        var bgImage: UIImage? = nil
        if let urlStr = quote.imageUrl, let url = URL(string: urlStr) {
            bgImage = await fetchImage(from: url)
        }
        return await MainActor.run { render(quote: quote, backgroundImage: bgImage) }
    }

    // MARK: - Core render

    private static func render(quote: Quote, backgroundImage: UIImage?) -> UIImage {
        let W: CGFloat = 1080
        let H: CGFloat = 1350
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // 1080×1350 pixel output (not @2x)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: format)

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // ── Layer 1: Background ──────────────────────────────────────────
            if let bgImage = backgroundImage {
                drawFillCrop(image: bgImage, in: cgCtx, canvasSize: CGSize(width: W, height: H))
            } else {
                drawGradientBackground(in: cgCtx, width: W, height: H)
            }

            // ── Layer 2: Dark overlay gradient ───────────────────────────────
            drawDarkOverlay(in: cgCtx, width: W, height: H)

            // ── Layers 3-7: Quote text block (vertically centred) ────────────
            drawTextContent(quote: quote, in: cgCtx, width: W, height: H)

            // ── Layer 8: App signature (bottom-right pill) ───────────────────
            drawSignature(in: cgCtx, width: W, height: H)
        }
    }

    // MARK: - Layer helpers

    private static func drawFillCrop(image: UIImage, in ctx: CGContext, canvasSize: CGSize) {
        let imgSize = image.size
        let scaleX = canvasSize.width  / imgSize.width
        let scaleY = canvasSize.height / imgSize.height
        let scale  = max(scaleX, scaleY)
        let scaledW = imgSize.width  * scale
        let scaledH = imgSize.height * scale
        let offsetX = (canvasSize.width  - scaledW) / 2
        let offsetY = (canvasSize.height - scaledH) / 2
        image.draw(in: CGRect(x: offsetX, y: offsetY, width: scaledW, height: scaledH))
    }

    private static func drawGradientBackground(in ctx: CGContext, width: CGFloat, height: CGFloat) {
        // #0C0C1E = rgb(12,12,30)  #1A0E2E = rgb(26,14,46)
        let colors: [CGFloat] = [
            12/255, 12/255, 30/255, 1,
            26/255, 14/255, 46/255, 1,
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: [0, 1],
            count: 2
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end:   CGPoint(x: width, y: height),
                options: []
            )
        }
    }

    private static func drawDarkOverlay(in ctx: CGContext, width: CGFloat, height: CGFloat) {
        let colors: [CGFloat] = [
            0, 0, 0, 0.45,
            0, 0, 0, 0.72,
            0, 0, 0, 0.92,
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: [0, 0.5, 1],
            count: 3
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end:   CGPoint(x: 0, y: height),
                options: []
            )
        }
    }

    private static func drawTextContent(quote: Quote, in ctx: CGContext, width: CGFloat, height: CGFloat) {
        let sidePad:     CGFloat = 130
        let maxTextW:    CGFloat = width - 2 * sidePad
        let lineHeight:  CGFloat = 70
        let quoteFont    = UIFont(name: "Georgia-Italic",  size: 52) ?? UIFont.italicSystemFont(ofSize: 52)
        let authorFont   = UIFont(name: "Georgia",         size: 38) ?? UIFont.systemFont(ofSize: 38)
        let animeFont    = UIFont.systemFont(ofSize: 26, weight: .bold)
        let dividerW:    CGFloat = 64
        let dividerH:    CGFloat = 2
        let gap1:        CGFloat = 56  // text → divider
        let gap2:        CGFloat = 40  // divider → author
        let gap3:        CGFloat = 16  // author → anime

        // Wrap quote text
        let quoteText  = quote.quote
        let lines      = wrapText(quoteText, font: quoteFont, maxWidth: maxTextW)
        let textH      = CGFloat(lines.count) * lineHeight
        let authorH:   CGFloat = 46
        let animeH:    CGFloat = 32

        let totalH = textH + gap1 + dividerH + gap2 + authorH + gap3 + animeH

        // Centre vertically; min Y = 240 so quote mark at 220 is not overlapped
        var startY = (height - totalH) / 2
        if startY < 240 { startY = 240 }

        // Draw decorative quote mark at (118, 220)
        let quoteMark = "\u{201C}" as NSString
        let quoteMarkFont = UIFont(name: "Georgia", size: 140) ?? UIFont.systemFont(ofSize: 140)
        let markAttrs: [NSAttributedString.Key: Any] = [
            .font: quoteMarkFont,
            .foregroundColor: UIColor(red: 0xA7 / 255.0, green: 0x8B / 255.0, blue: 0xFA / 255.0, alpha: 0.22),
        ]
        quoteMark.draw(at: CGPoint(x: 118, y: 220), withAttributes: markAttrs)

        // Draw each line of the quote
        var currentY = startY
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: quoteFont,
            .foregroundColor: UIColor.white,
        ]
        for line in lines {
            let lineStr = line as NSString
            let lineSize = lineStr.size(withAttributes: lineAttrs)
            let lineX = (width - lineSize.width) / 2
            lineStr.draw(at: CGPoint(x: lineX, y: currentY), withAttributes: lineAttrs)
            currentY += lineHeight
        }

        currentY += gap1

        // Draw divider
        let dividerX = (width - dividerW) / 2
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.33).cgColor)
        ctx.fill(CGRect(x: dividerX, y: currentY, width: dividerW, height: dividerH))
        currentY += dividerH + gap2

        // Draw author
        let authorStr  = "— \(quote.author)" as NSString
        let authorAttrs: [NSAttributedString.Key: Any] = [
            .font: authorFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.80),
        ]
        let authorSize = authorStr.size(withAttributes: authorAttrs)
        authorStr.draw(
            at: CGPoint(x: (width - authorSize.width) / 2, y: currentY),
            withAttributes: authorAttrs
        )
        currentY += authorH + gap3

        // Draw anime name
        let animeStr   = quote.anime.uppercased() as NSString
        let animeAttrs: [NSAttributedString.Key: Any] = [
            .font: animeFont,
            .foregroundColor: UIColor(red: 0xA7 / 255.0, green: 0x8B / 255.0, blue: 0xFA / 255.0, alpha: 1),
            .kern: 4.0,
        ]
        let animeSize = animeStr.size(withAttributes: animeAttrs)
        animeStr.draw(
            at: CGPoint(x: (width - animeSize.width) / 2, y: currentY),
            withAttributes: animeAttrs
        )
    }

    private static func drawSignature(in ctx: CGContext, width: CGFloat, height: CGFloat) {
        let pillH:       CGFloat = 56 + 14 * 2   // icon + vertical padding
        let marginR:     CGFloat = 52
        let marginB:     CGFloat = 60
        let hPad:        CGFloat = 18
        let iconSize:    CGFloat = 56
        let spacing:     CGFloat = 10
        let appName              = "Quote Anime"
        let nameFont             = UIFont.systemFont(ofSize: 24, weight: .bold)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.90),
        ]
        let nameSize = (appName as NSString).size(withAttributes: nameAttrs)
        let pillW    = hPad + iconSize + spacing + nameSize.width + hPad

        let pillX = width  - marginR - pillW
        let pillY = height - marginB - pillH

        // Pill background
        let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(pillPath.cgPath)
        ctx.fillPath()

        // App icon (if available)
        let iconX = pillX + hPad
        let iconY = pillY + (pillH - iconSize) / 2
        if let appIcon = appIconImage() {
            let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            // Clip to circle
            let circlePath = UIBezierPath(ovalIn: iconRect)
            ctx.saveGState()
            ctx.addPath(circlePath.cgPath)
            ctx.clip()
            appIcon.draw(in: iconRect)
            ctx.restoreGState()
        }

        // App name
        let nameX = iconX + iconSize + spacing
        let nameY = pillY + (pillH - nameSize.height) / 2
        (appName as NSString).draw(at: CGPoint(x: nameX, y: nameY), withAttributes: nameAttrs)
    }

    // MARK: - Utilities

    private static func wrapText(_ text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        for word in words {
            let test = current.isEmpty ? word : current + " " + word
            let testW = (test as NSString).size(withAttributes: attrs).width
            if testW <= maxWidth {
                current = test
            } else {
                if !current.isEmpty { lines.append(current) }
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

    private static func appIconImage() -> UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let lastName = files.last
        else { return nil }
        return UIImage(named: lastName)
    }

    private static func fetchImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }
}
