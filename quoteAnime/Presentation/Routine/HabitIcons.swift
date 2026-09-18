import Foundation

struct HabitIconCategory: Identifiable {
    let id: String
    /// Display name only; `id` is the stable identifier.
    let title: LocalizedStringResource
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

    /// VoiceOver name of every icon: Android's `icon_*` strings (`HabitIcons.describeIcon`), with
    /// the Spanish text as catalog key like the rest of the app. Every key in `categories` must
    /// have an entry here — `HabitIconLabelTests` walks all of them in both languages.
    private static let labelByKey: [String: LocalizedStringResource] = [
        // physical
        "dumbbell": "Entrenar",
        "running": "Correr",
        "directions_walk": "Caminar",
        "cycling": "Andar en bici",
        "swimming": "Nadar",
        "self_improvement": "Meditar",
        // mind
        "book": "Leer",
        "headphones": "Escuchar",
        "bedtime": "Dormir temprano",
        "wb_sunny": "Mañana",
        "nights_stay": "Noche",
        "water_drop": "Beber agua",
        // study
        "school": "Estudiar",
        "edit_note": "Escribir",
        "laptop": "Trabajar",
        "notebook": "Tomar notas",
        "folder": "Organizar",
        "alarm": "Madrugar",
        // routine
        "restaurant": "Comer",
        "clean_hands": "Higiene",
        "cleaning": "Limpiar",
        "bed": "Tender la cama",
        "spa": "Cuidado personal",
        "pets": "Cuidar mascota",
        // nutrition
        "local_dining": "Comer sano",
        "breakfast_dining": "Desayunar",
        "lunch_dining": "Almorzar",
        "dinner_dining": "Cenar",
        "icecream": "Darte un gusto",
        "local_cafe": "Tomar café",
        "egg": "Cocinar",
        "monitor_weight": "Controlar el peso",
        "medication": "Tomar vitaminas",
        "health_and_safety": "Chequeo médico",
        "vaccines": "Cuidar la salud",
        "bloodtype": "Controlar la salud",
        // home
        "local_laundry": "Lavar la ropa",
        "iron": "Planchar",
        "recycling": "Reciclar",
        "delete_sweep": "Sacar la basura",
        "shopping_cart": "Hacer la compra",
        "checkroom": "Ordenar el armario",
        "plumbing": "Reparar cosas",
        "handyman": "Hacer bricolaje",
        "chair": "Ordenar la casa",
        "countertops": "Limpiar la cocina",
        "kitchen": "Cocinar en casa",
        "home_repair_service": "Mantenimiento del hogar",
        // finance
        "savings": "Ahorrar dinero",
        "account_balance_wallet": "Hacer presupuesto",
        "attach_money": "Controlar gastos",
        "receipt_long": "Anotar gastos",
        "trending_up": "Hacer crecer tus ahorros",
        "task_alt": "Completar tareas",
        "checklist": "Planificar el día",
        "assignment_turned_in": "Terminar una tarea",
        "calendar_month": "Planificar la agenda",
        "timer": "Sesión de enfoque",
        "schedule": "Bloquear tiempo",
        "bar_chart": "Revisar tus objetivos",
        // creativity
        "palette": "Pintar",
        "brush": "Dibujar",
        "music_note": "Tocar música",
        "piano": "Practicar piano",
        "camera_alt": "Hacer fotos",
        "videocam": "Grabar vídeo",
        "mic": "Cantar o grabar",
        "extension": "Hacer un puzle",
        "sports_esports": "Jugar videojuegos",
        "casino": "Jugar un juego de mesa",
        "design_services": "Diseñar",
        "podcasts": "Escuchar un pódcast",
        // social
        "groups": "Quedar con amigos",
        "people": "Socializar",
        "favorite": "Mostrar cariño",
        "call": "Llamar a la familia",
        "chat": "Escribir a un amigo",
        "celebration": "Celebrar",
        "card_giftcard": "Hacer un regalo",
        "handshake": "Hacer contactos",
        "volunteer_activism": "Ser voluntario",
        "family_restroom": "Tiempo en familia",
        // nature
        "park": "Ir al parque",
        "hiking": "Hacer senderismo",
        "terrain": "Explorar senderos",
        "beach_access": "Día de playa",
        "forest": "Paseo por la naturaleza",
        "grass": "Cuidar el jardín",
        "local_florist": "Cuidar las plantas",
        "waves": "Nadar al aire libre",
        "sailing": "Navegar",
        "kayaking": "Hacer kayak",
        "wb_twilight": "Ver el atardecer",
        "landscape": "Contemplar el paisaje",
        // technology
        "smartphone": "Limitar las pantallas",
        "computer": "Trabajar en el ordenador",
        "tv": "Ver con moderación",
        "headset": "Hacer videollamada",
        "keyboard": "Escribir o programar",
        "notifications_off": "Desconexión digital",
        "do_not_disturb": "Modo concentración",
        "tablet": "Usar la tablet",
        "desktop_windows": "Trabajar en el escritorio",
        "videogame_asset": "Controlar tiempo de juego",
        // selfcare
        "bathtub": "Darte un baño",
        "hot_tub": "Relajarte",
        "mood": "Revisar tu ánimo",
        "sentiment_very_satisfied": "Practicar gratitud",
        "nightlight_round": "Relajarte antes de dormir",
        "psychology": "Reflexionar",
        "face": "Cuidar la piel",
        "emoji_emotions": "Anotar tus emociones",
        "weekend": "Tomarte un descanso",
        "auto_awesome": "Darte un capricho",
        // sports
        "sports_basketball": "Jugar baloncesto",
        "sports_soccer": "Jugar fútbol",
        "sports_tennis": "Jugar tenis",
        "sports_golf": "Jugar golf",
        "sports_volleyball": "Jugar vóleibol",
        "sports_martial_arts": "Practicar artes marciales",
        "skateboarding": "Andar en patineta",
        "surfing": "Hacer surf",
        "local_fire_department": "Mantener la racha",
        "emoji_events": "Celebrar un logro",
        "military_tech": "Ganar una insignia",
        "flag": "Fijar una meta"
    ]

    /// What VoiceOver says for an icon. Legacy keys resolve like `symbol(for:)` does. An unknown
    /// key reads as the generic "Ícono" — Android falls back to the raw key, but reading
    /// `home_repair_service` aloud helps nobody, and `HabitIconLabelTests` keeps that branch unreachable
    /// for every key the picker offers.
    static func label(for key: String) -> LocalizedStringResource {
        labelByKey[HabitIconAliases.canonical(key)] ?? "Ícono"
    }

    /// Resolves legacy keys too (`HabitIconAliases`), so no caller can ever show the generic check
    /// for a habit that was created from a template before the key fix.
    static func symbol(for key: String) -> String {
        symbolByKey[HabitIconAliases.canonical(key)] ?? "checkmark.circle.fill"
    }

    /// True when `key` resolves to a real glyph instead of the generic fallback.
    static func isKnown(_ key: String) -> Bool {
        symbolByKey[HabitIconAliases.canonical(key)] != nil
    }

    static let allKeys: [String] = categories.flatMap { $0.keys }
}
