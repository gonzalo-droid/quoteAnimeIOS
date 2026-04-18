import WidgetKit
import SwiftUI
import UIKit

// MARK: - Configuration
// ⚠️ Fill in your Firebase project URL.
// Find it in: Firebase Console → Realtime Database → Data tab (top of page)
// or in GoogleService-Info.plist → DATABASE_URL
private let kFirebaseDatabaseURL = "https://quoteanime-76a76-default-rtdb.firebaseio.com"

private let kAppGroupSuite = "group.com.gonzadev.quoteAnime"

private enum SharedKey {
    static let quoteText   = "widget_quote_text"
    static let quoteAuthor = "widget_quote_author"
    static let quoteAnime  = "widget_quote_anime"
    static let imageUrl    = "widget_image_url"
}

// MARK: - Helpers

private extension Int {
    /// Returns nil when the Int is zero, used to safely handle missing UserDefaults values.
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - Theme (inline — widget target has no access to app's Theme/)

private extension Color {
    static let wBgDark       = Color(red: 0.047, green: 0.047, blue: 0.118) // #0C0C1E
    static let wSurface      = Color(red: 0.094, green: 0.102, blue: 0.180) // #181A2E
    static let wAccentPurple = Color(red: 0.655, green: 0.545, blue: 0.980) // #A78BFA
    static let wTextPrimary  = Color(red: 0.941, green: 0.918, blue: 1.000) // #F0EAFF
    static let wTextSecond   = Color(red: 0.608, green: 0.553, blue: 0.702) // #9B8DB3
}

// MARK: - Entry

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quoteText: String
    let author: String
    let anime: String
    let backgroundImageData: Data?

    static let placeholder = QuoteEntry(
        date: .now,
        quoteText: "El esfuerzo supera al talento cuando el talento no se esfuerza.",
        author: "Rock Lee",
        anime: "Naruto",
        backgroundImageData: nil
    )
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
            backgroundImageData: imageData
        )
    }

    private static func fetchRandomQuote() async
        -> (text: String, author: String, anime: String, animeSlug: String?)? {
        guard let url = URL(string: "\(kFirebaseDatabaseURL)/quotes.json?limitToFirst=100") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        var quotes: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            quotes = array
        } else if let dict = json as? [String: Any] {
            quotes = dict.values.compactMap { $0 as? [String: Any] }
        }

        guard
            let q      = quotes.randomElement(),
            let text   = q["quote"]  as? String,
            let author = q["author"] as? String,
            let anime  = q["anime"]  as? String
        else { return nil }

        return (text, author, anime, q["animeSlug"] as? String)
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
        return try? await URLSession.shared.data(from: imageURL).0
    }

    /// Reads the last quote written by the main app from the shared App Group.
    static func readAppGroup() -> QuoteEntry {
        let d = UserDefaults(suiteName: kAppGroupSuite)
        var imageData: Data? = nil
        if let urlStr = d?.string(forKey: SharedKey.imageUrl), let url = URL(string: urlStr) {
            imageData = try? Data(contentsOf: url) // only works for local/cached URLs
        }
        return QuoteEntry(
            date: .now,
            quoteText: d?.string(forKey: SharedKey.quoteText)   ?? QuoteEntry.placeholder.quoteText,
            author:    d?.string(forKey: SharedKey.quoteAuthor) ?? QuoteEntry.placeholder.author,
            anime:     d?.string(forKey: SharedKey.quoteAnime)  ?? QuoteEntry.placeholder.anime,
            backgroundImageData: imageData
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
            .integer(forKey: "widget_update_times_per_day")
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
            Text("\u{201C}")
                .font(.custom("Georgia", size: 32))
                .foregroundColor(.wAccentPurple.opacity(0.6))
                .padding(.bottom, -10)

            Text(entry.quoteText)
                .font(.custom("Georgia-Italic", size: 12))
                .foregroundColor(.wTextPrimary)
                .lineSpacing(3)
                .lineLimit(5)

            Spacer(minLength: 6)

            Text("— \(entry.author)")
                .font(.custom("Georgia", size: 10))
                .foregroundColor(.wTextPrimary.opacity(0.8))

            Text(entry.anime.uppercased())
                .font(.system(size: 8, weight: .bold))
                .kerning(1.5)
                .foregroundColor(.wAccentPurple)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// Medium widget — content only, no background (background injected by caller)
struct QuoteWidgetMediumContent: View {
    let entry: QuoteEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{201C}")
                .font(.custom("Georgia", size: 48))
                .foregroundColor(.wAccentPurple.opacity(0.5))
                .padding(.bottom, -14)

            Text(entry.quoteText)
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(.wTextPrimary)
                .lineSpacing(4)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 1)
                .padding(.vertical, 10)

            Text("— \(entry.author)")
                .font(.custom("Georgia", size: 11))
                .foregroundColor(.wTextPrimary.opacity(0.85))

            Text(entry.anime.uppercased())
                .font(.system(size: 9, weight: .bold))
                .kerning(2)
                .foregroundColor(.wAccentPurple)
                .padding(.top, 3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// Entry-point view
// Lock screen rectangular — quote text only, system vibrant rendering
struct QuoteWidgetLockScreenContent: View {
    let entry: QuoteEntry
    var body: some View {
        Text(entry.quoteText)
            .font(.custom("SF Pro", size: 14))
            .lineSpacing(1)
            .lineLimit(3)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetAccentable()
    }
}

// Lock screen inline — single line (shown above the clock)
struct QuoteWidgetInlineContent: View {
    let entry: QuoteEntry
    var body: some View {
        // Inline only supports a single Label or Text — keep it short
        Text("\u{201C} \(entry.quoteText)")
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
            if #available(iOS 17.0, *) {
                QuoteAnimeWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        QuoteWidgetBackground(imageData: entry.backgroundImageData)
                    }
            } else {
                QuoteAnimeWidgetEntryView(entry: entry)
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
            QuoteAnimeLockWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Quote Anime — Lock Screen")
        .description("Una frase de anime en tu pantalla de bloqueo.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    QuoteAnimeWidget()
} timeline: {
    QuoteEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    QuoteAnimeWidget()
} timeline: {
    QuoteEntry.placeholder
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    QuoteAnimeLockWidget()
} timeline: {
    QuoteEntry.placeholder
}

#Preview("Lock Inline", as: .accessoryInline) {
    QuoteAnimeLockWidget()
} timeline: {
    QuoteEntry.placeholder
}
