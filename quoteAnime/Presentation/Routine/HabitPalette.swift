import SwiftUI

/// Fixed 14-color list, persisted by index (not hex) on `Habit.colorIndex`. Order must never
/// change — mirrors Android's `HabitPalette.kt` exactly so the two platforms agree on meaning.
enum HabitPalette {
    static let colors: [Color] = [
        Color(hex: "#A78BFA"), // 0 purple
        Color(hex: "#FF6B8A"), // 1 rose
        Color(hex: "#4ADE80"), // 2 green
        Color(hex: "#38BDF8"), // 3 sky
        Color(hex: "#FBBF24"), // 4 amber
        Color(hex: "#FB7185"), // 5 coral
        Color(hex: "#2DD4BF"), // 6 teal
        Color(hex: "#E879F9"), // 7 fuchsia
        Color(hex: "#818CF8"), // 8 indigo
        Color(hex: "#A3E635"), // 9 lime
        Color(hex: "#FB923C"), // 10 orange
        Color(hex: "#F87171"), // 11 red
        Color(hex: "#67E8F9"), // 12 cyan
        Color(hex: "#F472B6")  // 13 pink
    ]

    static func color(at index: Int) -> Color {
        let count = colors.count
        let wrapped = ((index % count) + count) % count
        return colors[wrapped]
    }
}
