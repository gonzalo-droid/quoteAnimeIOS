import Foundation

struct HabitIconCategory: Identifiable {
    let id: String
    let title: String
    let keys: [String]
}

/// Icons are stored by stable string key on `Habit.iconKey`, never a raw symbol name — keeps
/// existing habits valid if a mapping is ever swapped for a nicer glyph later. Keys mirror
/// Android's `HabitIcons.kt` category/key layout so the two platforms describe habits the same
/// way, even though the underlying glyph technology (SF Symbols vs Material) differs.
enum HabitIcons {
    static let categories: [HabitIconCategory] = [
        HabitIconCategory(id: "physical", title: "Físico", keys: [
            "dumbbell", "running", "directions_walk", "cycling", "swimming", "self_improvement"
        ]),
        HabitIconCategory(id: "mind", title: "Mente", keys: [
            "book", "headphones", "bedtime", "wb_sunny", "nights_stay", "water_drop"
        ]),
        HabitIconCategory(id: "study", title: "Estudio", keys: [
            "school", "edit_note", "laptop", "notebook", "folder", "alarm"
        ]),
        HabitIconCategory(id: "routine", title: "Rutina", keys: [
            "restaurant", "clean_hands", "cleaning", "bed", "spa", "pets"
        ]),
        HabitIconCategory(id: "nutrition", title: "Nutrición", keys: [
            "local_dining", "breakfast_dining", "lunch_dining", "dinner_dining", "icecream",
            "local_cafe", "egg", "monitor_weight", "medication", "health_and_safety",
            "vaccines", "bloodtype"
        ]),
        HabitIconCategory(id: "home", title: "Hogar", keys: [
            "local_laundry", "iron", "recycling", "delete_sweep", "shopping_cart", "checkroom",
            "plumbing", "handyman", "chair", "countertops", "kitchen", "home_repair_service"
        ]),
        HabitIconCategory(id: "finance", title: "Finanzas", keys: [
            "savings", "account_balance_wallet", "attach_money", "receipt_long", "trending_up",
            "task_alt", "checklist", "assignment_turned_in", "calendar_month", "timer",
            "schedule", "bar_chart"
        ]),
        HabitIconCategory(id: "creativity", title: "Creatividad", keys: [
            "palette", "brush", "music_note", "piano", "camera_alt", "videocam", "mic",
            "extension", "sports_esports", "casino", "design_services", "podcasts"
        ]),
        HabitIconCategory(id: "social", title: "Social", keys: [
            "groups", "people", "favorite", "call", "chat", "celebration", "card_giftcard",
            "handshake", "volunteer_activism", "family_restroom"
        ]),
        HabitIconCategory(id: "nature", title: "Naturaleza", keys: [
            "park", "hiking", "terrain", "beach_access", "forest", "grass", "local_florist",
            "waves", "sailing", "kayaking", "wb_twilight", "landscape"
        ]),
        HabitIconCategory(id: "technology", title: "Tecnología", keys: [
            "smartphone", "computer", "tv", "headset", "keyboard", "notifications_off",
            "do_not_disturb", "tablet", "desktop_windows", "videogame_asset"
        ]),
        HabitIconCategory(id: "selfcare", title: "Autocuidado", keys: [
            "bathtub", "hot_tub", "mood", "sentiment_very_satisfied", "nightlight_round",
            "psychology", "face", "emoji_emotions", "weekend", "auto_awesome"
        ]),
        HabitIconCategory(id: "sports", title: "Deportes", keys: [
            "sports_basketball", "sports_soccer", "sports_tennis", "sports_golf",
            "sports_volleyball", "sports_martial_arts", "skateboarding", "surfing",
            "local_fire_department", "emoji_events", "military_tech", "flag"
        ])
    ]

    private static let symbolByKey: [String: String] = [
        // physical
        "dumbbell": "dumbbell.fill", "running": "figure.run", "directions_walk": "figure.walk",
        "cycling": "figure.outdoor.cycle", "swimming": "figure.pool.swim",
        "self_improvement": "figure.mind.and.body",
        // mind
        "book": "book.fill", "headphones": "headphones", "bedtime": "moon.zzz.fill",
        "wb_sunny": "sun.max.fill", "nights_stay": "moon.stars.fill", "water_drop": "drop.fill",
        // study
        "school": "graduationcap.fill", "edit_note": "square.and.pencil", "laptop": "laptopcomputer",
        "notebook": "book.closed.fill", "folder": "folder.fill", "alarm": "alarm.fill",
        // routine
        "restaurant": "fork.knife", "clean_hands": "hands.and.sparkles.fill",
        "cleaning": "sparkles", "bed": "bed.double.fill", "spa": "leaf.fill", "pets": "pawprint.fill",
        // nutrition
        "local_dining": "fork.knife.circle.fill", "breakfast_dining": "cup.and.saucer.fill",
        "lunch_dining": "takeoutbag.and.cup.and.straw.fill", "dinner_dining": "wineglass.fill",
        "icecream": "snowflake", "local_cafe": "cup.and.saucer.fill", "egg": "oval.fill",
        "monitor_weight": "scalemass.fill", "medication": "pills.fill",
        "health_and_safety": "cross.case.fill", "vaccines": "syringe.fill", "bloodtype": "drop.circle.fill",
        // home
        "local_laundry": "washer.fill", "iron": "iron.fill", "recycling": "arrow.3.trianglepath",
        "delete_sweep": "trash.fill", "shopping_cart": "cart.fill", "checkroom": "tshirt.fill",
        "plumbing": "wrench.and.screwdriver.fill", "handyman": "hammer.fill",
        "chair": "chair.fill", "countertops": "table.furniture.fill", "kitchen": "refrigerator.fill",
        "home_repair_service": "house.and.flag.fill",
        // finance
        "savings": "banknote.fill", "account_balance_wallet": "wallet.pass.fill",
        "attach_money": "dollarsign.circle.fill", "receipt_long": "receipt.fill",
        "trending_up": "chart.line.uptrend.xyaxis", "task_alt": "checkmark.circle.fill",
        "checklist": "checklist", "assignment_turned_in": "doc.badge.checkmark.fill",
        "calendar_month": "calendar", "timer": "timer", "schedule": "clock.fill",
        "bar_chart": "chart.bar.fill",
        // creativity
        "palette": "paintpalette.fill", "brush": "paintbrush.fill", "music_note": "music.note",
        "piano": "pianokeys", "camera_alt": "camera.fill", "videocam": "video.fill",
        "mic": "mic.fill", "extension": "puzzlepiece.fill", "sports_esports": "gamecontroller.fill",
        "casino": "die.face.5.fill", "design_services": "pencil.and.ruler.fill",
        "podcasts": "dot.radiowaves.left.and.right",
        // social
        "groups": "person.3.fill", "people": "person.2.fill", "favorite": "heart.fill",
        "call": "phone.fill", "chat": "bubble.left.and.bubble.right.fill",
        "celebration": "party.popper.fill", "card_giftcard": "gift.fill",
        "handshake": "hands.clap.fill", "volunteer_activism": "heart.circle.fill",
        "family_restroom": "figure.2.and.child.holdinghands",
        // nature
        "park": "tree.fill", "hiking": "figure.hiking", "terrain": "mountain.2.fill",
        "beach_access": "beach.umbrella.fill", "forest": "leaf.fill", "grass": "leaf.fill",
        "local_florist": "camera.macro", "waves": "water.waves", "sailing": "sailboat.fill",
        "kayaking": "figure.outdoor.rowing", "wb_twilight": "sunset.fill",
        "landscape": "photo.fill",
        // technology
        "smartphone": "iphone", "computer": "desktopcomputer", "tv": "tv.fill",
        "headset": "headphones", "keyboard": "keyboard.fill",
        "notifications_off": "bell.slash.fill", "do_not_disturb": "moon.circle.fill",
        "tablet": "ipad", "desktop_windows": "display", "videogame_asset": "gamecontroller.fill",
        // selfcare
        "bathtub": "bathtub.fill", "hot_tub": "figure.pool.swim", "mood": "face.smiling.fill",
        "sentiment_very_satisfied": "face.smiling.fill", "nightlight_round": "moon.fill",
        "psychology": "brain.head.profile", "face": "face.smiling", "emoji_emotions": "smiley.fill",
        "weekend": "sofa.fill", "auto_awesome": "sparkles",
        // sports
        "sports_basketball": "basketball.fill", "sports_soccer": "soccerball",
        "sports_tennis": "tennisball.fill", "sports_golf": "figure.golf",
        "sports_volleyball": "volleyball.fill", "sports_martial_arts": "figure.martial.arts",
        "skateboarding": "figure.skating", "surfing": "figure.surfing",
        "local_fire_department": "flame.fill", "emoji_events": "trophy.fill",
        "military_tech": "medal.fill", "flag": "flag.fill"
    ]

    static func symbol(for key: String) -> String {
        symbolByKey[key] ?? "checkmark.circle.fill"
    }

    static let allKeys: [String] = categories.flatMap { $0.keys }
}
