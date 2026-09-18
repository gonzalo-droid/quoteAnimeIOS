import WidgetKit
import SwiftUI
import UIKit
import ImageIO

// MARK: - Configuration
// ⚠️ Fill in your Firebase project URL.
// Find it in: Firebase Console → Realtime Database → Data tab (top of page)
// or in GoogleService-Info.plist → DATABASE_URL
private let kFirebaseDatabaseURL = "https://quoteanime-76a76-default-rtdb.firebaseio.com"

// App Group suite and keys: `WidgetSharedModel.swift`.

// MARK: - Helpers

private extension Int {
    /// Returns nil when the Int is zero, used to safely handle missing UserDefaults values.
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - Theme (inline — widget target has no access to app's Theme/)
// Not `private`: `RoutineSummaryWidget.swift` (same target) reuses these.

extension Color {
    static let wBgDark       = Color(red: 0.047, green: 0.047, blue: 0.118) // #0C0C1E
    static let wSurface      = Color(red: 0.094, green: 0.102, blue: 0.180) // #181A2E
    static let wAccentPurple = Color(red: 0.655, green: 0.545, blue: 0.980) // #A78BFA
    static let wTextPrimary  = Color(red: 0.941, green: 0.918, blue: 1.000) // #F0EAFF
    static let wTextSecond   = Color(red: 0.608, green: 0.553, blue: 0.702) // #9B8DB3
}

// MARK: - Typography (hand-mirrored from the app's `Theme/Typography.swift`)
// Same rule as the app: a size that is a text style's default size uses that style; any other
// size scales along the nearest style. Every widget view caps the range, because a widget's frame
// never grows with the text: `wMaxDynamicTypeSize` for the routine widgets,
// `wQuoteMaxDynamicTypeSize` for the quote widgets.

/// The largest text size the routine widgets follow. A system widget has a fixed frame, so past
/// this the habit rows would only get cut.
let wMaxDynamicTypeSize = DynamicTypeSize.xLarge

/// The quote widgets don't grow at all: a three-line quote already fills the medium widget at the
/// default size, and at `.xLarge` it collapsed to a single truncated line (seen in the simulator
/// with a 117-character quote). The quote *is* the widget, so it keeps its design size; the app
/// shows the same quote at the user's size one tap away.
let wQuoteMaxDynamicTypeSize = DynamicTypeSize.large

enum WTypography {
    static let defaultSizes: [(style: Font.TextStyle, size: CGFloat)] = [
        (.caption2, 11), (.caption, 12), (.footnote, 13), (.subheadline, 15), (.callout, 16),
        (.body, 17), (.title3, 20), (.title2, 22), (.title, 28), (.largeTitle, 34),
    ]

    static func textStyle(forSize size: CGFloat) -> Font.TextStyle {
        defaultSizes.min { abs($0.size - size) < abs($1.size - size) }?.style ?? .body
    }
}

extension Font {
    static func wQuoteSerif(size: CGFloat) -> Font {
        .custom("Didot", size: size, relativeTo: WTypography.textStyle(forSize: size))
    }

    static func wQuoteSerifItalic(size: CGFloat) -> Font {
        .custom("Georgia", size: size, relativeTo: WTypography.textStyle(forSize: size))
    }
}

private struct WScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: WTypography.textStyle(forSize: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// The app's `scaledFont(size:weight:)`, for the widget target.
    func wScaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(WScaledSystemFont(size: size, weight: weight))
    }
}

// MARK: - Entry

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quoteText: String
    let author: String
    let anime: String
    let backgroundImageData: Data?
    /// The app's `Quote.id` of the quote shown, for the tap's deep link. Nil for the placeholder
    /// (a tap then just opens the app).
    let quoteId: String?

    static let placeholder = QuoteEntry(
        date: .now,
        quoteText: "El esfuerzo supera al talento cuando el talento no se esfuerza.",
        author: "Rock Lee",
        anime: "Naruto",
        backgroundImageData: nil,
        quoteId: nil
    )

    /// Where tapping the widget opens the app: Home, on this quote.
    var openURL: URL? { quoteId.flatMap(WidgetDeepLink.quote(id:)) }
}

// MARK: - Network Service

private enum WidgetNetworkService {

    /// Fetches a random quote + its background image from Firebase REST API.
    /// Returns nil if the network is unavailable or the response can't be parsed.
    static func fetchEntry() async -> QuoteEntry? {
        guard let quote = await fetchRandomQuote() else { return nil }
        let imageData: Data?
        if let slug = quote.animeSlug, !slug.isEmpty {
            imageData = await fetchImageData(forSlug: slug)
        } else {
            imageData = nil
        }
        return QuoteEntry(
            date: .now,
            quoteText: quote.text,
            author: quote.author,
            anime: quote.anime,
            backgroundImageData: imageData,
            quoteId: quote.id
        )
    }

    private static func fetchRandomQuote() async
        -> (text: String, author: String, anime: String, animeSlug: String?, id: String?)? {
        // The whole node, with no `limitToFirst`. It used to ask for the first 100 keys, which
        // meant the widget could only ever show quotes from that fixed slice — and, now that the
        // anime selection is honoured, would have shown nothing at all to anyone whose animes
        // happened to live outside it. (`orderBy` was only there because Firebase REST demands it
        // alongside `limitToFirst`, so it goes away with it.)
        guard let url = URL(string: "\(kFirebaseDatabaseURL)/quotes.json") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        // The node key is kept: it is the quote's id in the app (`WidgetQuoteID`).
        var quotes: [(key: String?, fields: [String: Any])] = []
        if let array = json as? [[String: Any]] {
            quotes = array.map { (nil, $0) }
        } else if let dict = json as? [String: Any] {
            quotes = dict.compactMap { key, value in (value as? [String: Any]).map { (key, $0) } }
        }

        guard
            let picked = pick(from: quotes, matching: selectedAnimes()),
            let text   = picked.fields["quote"]  as? String,
            let author = picked.fields["author"] as? String,
            let anime  = picked.fields["anime"]  as? String
        else { return nil }

        return (text, author, anime, picked.fields["animeSlug"] as? String,
                WidgetQuoteID.resolve(fields: picked.fields, key: picked.key))
    }

    /// The animes the user picked in Ajustes → Contenido → Animes, mirrored into the App Group by
    /// `UserPreferencesStore`. Empty (or absent) means "all animes" — never "no animes".
    static func selectedAnimes() -> Set<String> {
        let stored = UserDefaults(suiteName: kAppGroupSuite)?
            .stringArray(forKey: WidgetSharedKey.selectedCategoryIds) ?? []
        return Set(stored)
    }

    /// Same rule as the app's `GetAllQuotesUseCase.filtered` and Android's
    /// `UpdateQuoteWidgetWorker` (`getRandomQuote(preferences.selectedCategoryIds)`): an empty
    /// selection means everything, and the id is the anime's exact name.
    ///
    /// The fallback matters. If the selection matches nothing in the catalogue — an anime that was
    /// renamed or withdrawn remotely — the widget shows a quote from the whole pool rather than an
    /// error, because a stale filter is not a reason to leave the home screen blank.
    static func pick(
        from quotes: [(key: String?, fields: [String: Any])],
        matching selection: Set<String>
    ) -> (key: String?, fields: [String: Any])? {
        guard !selection.isEmpty else { return quotes.randomElement() }
        let filtered = quotes.filter { quote in
            guard let anime = quote.fields["anime"] as? String else { return false }
            return selection.contains(anime)
        }
        return filtered.randomElement() ?? quotes.randomElement()
    }

    static func fetchImageData(forSlug slug: String) async -> Data? {
        guard !slug.isEmpty,
              let url = URL(string: "\(kFirebaseDatabaseURL)/imagenes/\(slug).json")
        else { return nil }

        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        var urls: [String] = []
        if let arr = json as? [String] {
            urls = arr
        } else if let dict = json as? [String: Any] {
            urls = dict
                .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
                .compactMap { $0.value as? String }
        }

        guard let first = urls.first, let imageURL = URL(string: first) else { return nil }
        guard let full = try? await URLSession.shared.data(from: imageURL).0 else { return nil }
        // Downsampled, never used at full size — see `downsampled(_:maxPixel:)`.
        return downsampled(full) ?? nil
    }

    /// Shrinks the artwork before it goes into a timeline entry.
    ///
    /// WidgetKit refuses to archive a timeline that carries an image much bigger than the widget
    /// itself: the anime covers come back at 1080×1350 and every single refresh failed with
    /// `ArchivingError.imageTooLarge(size: (1080, 1350), maximumSize: (1084.6, 986))`, so the
    /// widget never left its grey placeholder — the quote it had fetched was simply thrown away.
    /// 600px on the long side still covers a 3× `systemMedium` and is a quarter of the bytes.
    /// Android downsamples for the same reason (`optimizedForDisplay()` plus an 85% JPEG in
    /// `UpdateQuoteWidgetWorker`).
    private static func downsampled(_ data: Data, maxPixel: CGFloat = 600) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85)
    }

    /// Reads the last quote written by the main app from the shared App Group.
    static func readAppGroup() -> QuoteEntry {
        let d = UserDefaults(suiteName: kAppGroupSuite)
        var imageData: Data? = nil
        if let urlStr = d?.string(forKey: WidgetSharedKey.imageUrl), let url = URL(string: urlStr) {
            // Only works for local/cached URLs — and it gets the same downsampling, for the same
            // archiving limit.
            imageData = (try? Data(contentsOf: url)).flatMap { downsampled($0) }
        }
        let storedText = d?.string(forKey: WidgetSharedKey.quoteText)
        return QuoteEntry(
            date: .now,
            quoteText: storedText ?? QuoteEntry.placeholder.quoteText,
            author:    d?.string(forKey: WidgetSharedKey.quoteAuthor) ?? QuoteEntry.placeholder.author,
            anime:     d?.string(forKey: WidgetSharedKey.quoteAnime)  ?? QuoteEntry.placeholder.anime,
            backgroundImageData: imageData,
            // Only with a stored quote: the placeholder text must not point at some other quote.
            quoteId:   storedText == nil ? nil : d?.string(forKey: WidgetSharedKey.quoteId)
        )
    }
}

// MARK: - Provider

struct QuoteProvider: TimelineProvider {

    func placeholder(in context: Context) -> QuoteEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await WidgetNetworkService.fetchEntry() ?? WidgetNetworkService.readAppGroup()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        Task {
            let entry = await WidgetNetworkService.fetchEntry() ?? WidgetNetworkService.readAppGroup()
            let next = Calendar.current.date(byAdding: .minute,
                                             value: refreshIntervalMinutes(),
                                             to: entry.date) ?? entry.date
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Converts the user-configured "times per day" into a minute interval.
    /// Reads from App Group so the widget extension can access it.
    /// Falls back to 2 times/day (720 min) if not set.
    private func refreshIntervalMinutes() -> Int {
        let timesPerDay = UserDefaults(suiteName: kAppGroupSuite)?
            .integer(forKey: WidgetSharedKey.updateTimesPerDay)
            .nonZero ?? 2
        return max(1, (24 * 60) / timesPerDay)
    }
}

// MARK: - Views

struct QuoteWidgetBackground: View {
    let imageData: Data?
    var body: some View {
        ZStack {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.wBgDark, Color.wSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            // Dark overlay identical to the app's QuoteDetailView
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.50), location: 0),
                    .init(color: .black.opacity(0.75), location: 0.5),
                    .init(color: .black.opacity(0.92), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// Small widget — content only, no background (background injected by caller)
struct QuoteWidgetSmallContent: View {
    let entry: QuoteEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.quoteText)
                .font(.wQuoteSerifItalic(size: 12))
                .foregroundColor(.wTextPrimary)
                .lineSpacing(3)
                .lineLimit(5)

            Spacer(minLength: 6)

            Text(verbatim: "— \(entry.author)")
                .font(.wQuoteSerif(size: 10))
                .foregroundColor(.wTextPrimary.opacity(0.8))

            Text(entry.anime.uppercased())
                .wScaledFont(size: 8, weight: .bold)
                .kerning(1.5)
                .foregroundColor(.wAccentPurple)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .dynamicTypeSize(...wQuoteMaxDynamicTypeSize)
    }
}

// Medium widget — content only, no background (background injected by caller)
struct QuoteWidgetMediumContent: View {
    let entry: QuoteEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.quoteText)
                .font(.wQuoteSerifItalic(size: 14))
                .foregroundColor(.wTextPrimary)
                .lineSpacing(4)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 1)
                .padding(.vertical, 10)

            Text(verbatim: "— \(entry.author)")
                .font(.wQuoteSerif(size: 11))
                .foregroundColor(.wTextPrimary.opacity(0.85))

            Text(entry.anime.uppercased())
                .wScaledFont(size: 9, weight: .bold)
                .kerning(2)
                .foregroundColor(.wAccentPurple)
                .padding(.top, 3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .dynamicTypeSize(...wQuoteMaxDynamicTypeSize)
    }
}

// Entry-point view
// Lock screen rectangular — quote text only, system vibrant rendering
struct QuoteWidgetLockScreenContent: View {
    let entry: QuoteEntry
    var body: some View {
        Text(entry.quoteText)
            .wScaledFont(size: 14)
            .lineSpacing(1)
            .lineLimit(3)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetAccentable()
            .dynamicTypeSize(...wQuoteMaxDynamicTypeSize)
    }
}

// Lock screen inline — single line (shown above the clock)
struct QuoteWidgetInlineContent: View {
    let entry: QuoteEntry
    var body: some View {
        // Inline only supports a single Label or Text — keep it short
        Text(entry.quoteText)
            .lineLimit(1)
            .widgetAccentable()
    }
}

// MARK: - Entry-point views

// Home screen entry view
// iOS 17+: transparent (containerBackground handles fill + corner clipping)
// iOS 16:  ZStack with explicit background to fill the widget frame
struct QuoteAnimeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuoteEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            homeContent
        } else {
            ZStack {
                QuoteWidgetBackground(imageData: entry.backgroundImageData)
                homeContent
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch family {
        case .systemMedium, .systemLarge:
            QuoteWidgetMediumContent(entry: entry)
        default:
            QuoteWidgetSmallContent(entry: entry)
        }
    }
}

// Lock screen entry view — no background, system handles rendering
struct QuoteAnimeLockWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuoteEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            QuoteWidgetInlineContent(entry: entry)
        default:
            QuoteWidgetLockScreenContent(entry: entry)
        }
    }
}

// MARK: - Widgets

struct QuoteAnimeWidget: Widget {
    let kind = "QuoteAnimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            // Tapping opens Home on this quote — Android's `widget_quote_id` open intent.
            if #available(iOS 17.0, *) {
                QuoteAnimeWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        QuoteWidgetBackground(imageData: entry.backgroundImageData)
                    }
                    .widgetURL(entry.openURL)
            } else {
                QuoteAnimeWidgetEntryView(entry: entry)
                    .widgetURL(entry.openURL)
            }
        }
        .configurationDisplayName("Quote Anime")
        .description("Una frase de anime en tu pantalla de inicio.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Lock screen widget — iOS 16+
struct QuoteAnimeLockWidget: Widget {
    let kind = "QuoteAnimeLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            // iOS 17+ requires an explicit container background; on iOS 16 the system
            // renders accessory widgets with its own vibrant treatment and the modifier
            // does not exist yet.
            // Same destination as the home-screen widget (Android has no lock-screen widget).
            if #available(iOS 17.0, *) {
                QuoteAnimeLockWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
                    .widgetURL(entry.openURL)
            } else {
                QuoteAnimeLockWidgetEntryView(entry: entry)
                    .widgetURL(entry.openURL)
            }
        }
        .configurationDisplayName("Quote Anime — Pantalla bloqueada")
        .description("Una frase de anime en tu pantalla bloqueada.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    QuoteAnimeWidget()
} timeline: {
    QuoteEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    QuoteAnimeWidget()
} timeline: {
    QuoteEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Lock Rectangular", as: .accessoryRectangular) {
    QuoteAnimeLockWidget()
} timeline: {
    QuoteEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Lock Inline", as: .accessoryInline) {
    QuoteAnimeLockWidget()
} timeline: {
    QuoteEntry.placeholder
}
