import Foundation

/// One child of `/habitTemplates` in the Realtime Database — Android's `HabitTemplateDto` and
/// `DataSnapshot.toHabitTemplateDto()` (`492f80f`). The node key is the template id.
///
/// Same rules as Android where Android has one: no `title` or no `iconKey` drops the template,
/// a missing `order` is 0, a missing `isPremiumOnly` is false, the theme fields are optional.
/// Where Android would throw on a value of the wrong type, iOS decides per field:
/// - `order` of the wrong type → 0 (it only sorts).
/// - `themeColorIndex` of the wrong type, or outside `HabitPalette` → nil (the habit keeps the
///   editor's colour instead of persisting an index no swatch has).
/// - `isPremiumOnly` of the wrong type → the template is **dropped**: guessing false would hand a
///   premium theme to everyone.
struct HabitTemplateDTO: Equatable {
    let id: String
    let title: String
    let iconKey: String
    let order: Int
    let themeColorIndex: Int?
    let themeKey: String?
    let isPremiumOnly: Bool

    init(
        id: String,
        title: String,
        iconKey: String,
        order: Int = 0,
        themeColorIndex: Int? = nil,
        themeKey: String? = nil,
        isPremiumOnly: Bool = false
    ) {
        self.id = id
        self.title = title
        self.iconKey = iconKey
        self.order = order
        self.themeColorIndex = themeColorIndex
        self.themeKey = themeKey
        self.isPremiumOnly = isPremiumOnly
    }

    init?(key: String, value: Any) {
        guard let dict = value as? [String: Any],
              let title = dict["title"] as? String,
              let iconKey = dict["iconKey"] as? String,
              !iconKey.isEmpty
        else { return nil }

        let isPremiumOnly: Bool
        switch dict["isPremiumOnly"] {
        case nil, is NSNull: isPremiumOnly = false
        case let flag as Bool: isPremiumOnly = flag
        default: return nil
        }

        let themeKey = (dict["themeKey"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.init(
            id: key,
            title: title,
            iconKey: iconKey,
            order: dict["order"] as? Int ?? 0,
            themeColorIndex: dict["themeColorIndex"] as? Int,
            themeKey: themeKey,
            isPremiumOnly: isPremiumOnly
        )
    }

    /// The whole node, as the SDK hands it over: a dictionary keyed by template id, an array when
    /// the keys happen to be 0…n (holes come back as `NSNull`), or `NSNull`/nil when it's missing.
    static func decodeNode(_ value: Any?) -> [HabitTemplateDTO] {
        if let dict = value as? [String: Any] {
            return dict.compactMap { HabitTemplateDTO(key: $0.key, value: $0.value) }
        }
        if let array = value as? [Any] {
            return array.enumerated().compactMap { HabitTemplateDTO(key: String($0.offset), value: $0.element) }
        }
        return []
    }

    /// Nil when the title is a key this build can't name — see `HabitTemplateTitles`.
    func toDomain(paletteSize: Int) -> HabitTemplate? {
        guard let displayTitle = HabitTemplateTitles.displayTitle(for: title) else { return nil }
        return HabitTemplate(
            id: id,
            title: displayTitle,
            iconKey: iconKey,
            order: order,
            themeColorIndex: themeColorIndex.flatMap { (0..<paletteSize).contains($0) ? $0 : nil },
            themeKey: themeKey,
            isPremiumOnly: isPremiumOnly
        )
    }
}
