import Foundation
import Testing
@testable import quoteAnime

/// VoiceOver names of the habit icons (Android `4f8e6d2`, `HabitIcons.describeIcon`). The keys are
/// persisted on `Habit.iconKey`, so a label silently missing for one of them is invisible in every
/// other test: the picker still draws the glyph and VoiceOver just reads the fallback.
@Suite("Etiquetas de accesibilidad de Mi Rutina")
struct HabitIconLabelTests {

    nonisolated static let spanish = Locale(identifier: "es")
    nonisolated static let english = Locale(identifier: "en")

    private static func resolve(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }

    /// Every icon the picker offers, with Android's `values-es` / `values` text for its `icon_*`
    /// string. One deliberate difference: `auto_awesome` is "Pamper yourself" in English, because
    /// Android's "Treat yourself" is also `icecream`'s and VoiceOver couldn't tell them apart.
    nonisolated static let androidTable: [(String, String, String)] = [
        ("dumbbell", "Entrenar", "Work out"),
        ("running", "Correr", "Run"),
        ("directions_walk", "Caminar", "Walk"),
        ("cycling", "Andar en bici", "Cycle"),
        ("swimming", "Nadar", "Swim"),
        ("self_improvement", "Meditar", "Meditate"),
        ("book", "Leer", "Read"),
        ("headphones", "Escuchar", "Listen"),
        ("bedtime", "Dormir temprano", "Sleep early"),
        ("wb_sunny", "Mañana", "Morning"),
        ("nights_stay", "Noche", "Night"),
        ("water_drop", "Beber agua", "Drink water"),
        ("school", "Estudiar", "Study"),
        ("edit_note", "Escribir", "Write"),
        ("laptop", "Trabajar", "Work"),
        ("notebook", "Tomar notas", "Take notes"),
        ("folder", "Organizar", "Organize"),
        ("alarm", "Madrugar", "Wake up early"),
        ("restaurant", "Comer", "Eat"),
        ("clean_hands", "Higiene", "Hygiene"),
        ("cleaning", "Limpiar", "Clean"),
        ("bed", "Tender la cama", "Make the bed"),
        ("spa", "Cuidado personal", "Self-care"),
        ("pets", "Cuidar mascota", "Pet care"),
        ("local_dining", "Comer sano", "Eat healthy"),
        ("breakfast_dining", "Desayunar", "Breakfast"),
        ("lunch_dining", "Almorzar", "Lunch"),
        ("dinner_dining", "Cenar", "Dinner"),
        ("icecream", "Darte un gusto", "Treat yourself"),
        ("local_cafe", "Tomar café", "Coffee"),
        ("egg", "Cocinar", "Cook"),
        ("monitor_weight", "Controlar el peso", "Track weight"),
        ("medication", "Tomar vitaminas", "Take vitamins"),
        ("health_and_safety", "Chequeo médico", "Health checkup"),
        ("vaccines", "Cuidar la salud", "Health care"),
        ("bloodtype", "Controlar la salud", "Track health"),
        ("local_laundry", "Lavar la ropa", "Do laundry"),
        ("iron", "Planchar", "Iron clothes"),
        ("recycling", "Reciclar", "Recycle"),
        ("delete_sweep", "Sacar la basura", "Take out trash"),
        ("shopping_cart", "Hacer la compra", "Grocery shop"),
        ("checkroom", "Ordenar el armario", "Organize closet"),
        ("plumbing", "Reparar cosas", "Fix things"),
        ("handyman", "Hacer bricolaje", "DIY repair"),
        ("chair", "Ordenar la casa", "Tidy up"),
        ("countertops", "Limpiar la cocina", "Clean kitchen"),
        ("kitchen", "Cocinar en casa", "Cook at home"),
        ("home_repair_service", "Mantenimiento del hogar", "Home maintenance"),
        ("savings", "Ahorrar dinero", "Save money"),
        ("account_balance_wallet", "Hacer presupuesto", "Budget"),
        ("attach_money", "Controlar gastos", "Track expenses"),
        ("receipt_long", "Anotar gastos", "Log expenses"),
        ("trending_up", "Hacer crecer tus ahorros", "Grow savings"),
        ("task_alt", "Completar tareas", "Complete tasks"),
        ("checklist", "Planificar el día", "Plan your day"),
        ("assignment_turned_in", "Terminar una tarea", "Finish an assignment"),
        ("calendar_month", "Planificar la agenda", "Plan your schedule"),
        ("timer", "Sesión de enfoque", "Focus session"),
        ("schedule", "Bloquear tiempo", "Block out time"),
        ("bar_chart", "Revisar tus objetivos", "Review your goals"),
        ("palette", "Pintar", "Paint"),
        ("brush", "Dibujar", "Draw"),
        ("music_note", "Tocar música", "Play music"),
        ("piano", "Practicar piano", "Practice piano"),
        ("camera_alt", "Hacer fotos", "Take photos"),
        ("videocam", "Grabar vídeo", "Record video"),
        ("mic", "Cantar o grabar", "Sing or record"),
        ("extension", "Hacer un puzle", "Solve a puzzle"),
        ("sports_esports", "Jugar videojuegos", "Play video games"),
        ("casino", "Jugar un juego de mesa", "Play a board game"),
        ("design_services", "Diseñar", "Design"),
        ("podcasts", "Escuchar un pódcast", "Listen to a podcast"),
        ("groups", "Quedar con amigos", "Spend time with friends"),
        ("people", "Socializar", "Socialize"),
        ("favorite", "Mostrar cariño", "Show love"),
        ("call", "Llamar a la familia", "Call family"),
        ("chat", "Escribir a un amigo", "Message a friend"),
        ("celebration", "Celebrar", "Celebrate"),
        ("card_giftcard", "Hacer un regalo", "Give a gift"),
        ("handshake", "Hacer contactos", "Network"),
        ("volunteer_activism", "Ser voluntario", "Volunteer"),
        ("family_restroom", "Tiempo en familia", "Family time"),
        ("park", "Ir al parque", "Visit a park"),
        ("hiking", "Hacer senderismo", "Hike"),
        ("terrain", "Explorar senderos", "Explore trails"),
        ("beach_access", "Día de playa", "Beach day"),
        ("forest", "Paseo por la naturaleza", "Nature walk"),
        ("grass", "Cuidar el jardín", "Garden"),
        ("local_florist", "Cuidar las plantas", "Tend plants"),
        ("waves", "Nadar al aire libre", "Swim outdoors"),
        ("sailing", "Navegar", "Sail"),
        ("kayaking", "Hacer kayak", "Kayak"),
        ("wb_twilight", "Ver el atardecer", "Watch the sunset"),
        ("landscape", "Contemplar el paisaje", "Admire the view"),
        ("smartphone", "Limitar las pantallas", "Limit screen time"),
        ("computer", "Trabajar en el ordenador", "Work on the computer"),
        ("tv", "Ver con moderación", "Watch mindfully"),
        ("headset", "Hacer videollamada", "Video call"),
        ("keyboard", "Escribir o programar", "Type or code"),
        ("notifications_off", "Desconexión digital", "Digital detox"),
        ("do_not_disturb", "Modo concentración", "Focus mode"),
        ("tablet", "Usar la tablet", "Use the tablet"),
        ("desktop_windows", "Trabajar en el escritorio", "Desk work"),
        ("videogame_asset", "Controlar tiempo de juego", "Track gaming time"),
        ("bathtub", "Darte un baño", "Take a bath"),
        ("hot_tub", "Relajarte", "Relax"),
        ("mood", "Revisar tu ánimo", "Check your mood"),
        ("sentiment_very_satisfied", "Practicar gratitud", "Practice gratitude"),
        ("nightlight_round", "Relajarte antes de dormir", "Wind down"),
        ("psychology", "Reflexionar", "Reflect"),
        ("face", "Cuidar la piel", "Skincare"),
        ("emoji_emotions", "Anotar tus emociones", "Journal your feelings"),
        ("weekend", "Tomarte un descanso", "Take a break"),
        ("auto_awesome", "Darte un capricho", "Pamper yourself"),
        ("sports_basketball", "Jugar baloncesto", "Play basketball"),
        ("sports_soccer", "Jugar fútbol", "Play soccer"),
        ("sports_tennis", "Jugar tenis", "Play tennis"),
        ("sports_golf", "Jugar golf", "Play golf"),
        ("sports_volleyball", "Jugar vóleibol", "Play volleyball"),
        ("sports_martial_arts", "Practicar artes marciales", "Practice martial arts"),
        ("skateboarding", "Andar en patineta", "Skateboard"),
        ("surfing", "Hacer surf", "Surf"),
        ("local_fire_department", "Mantener la racha", "Keep your streak"),
        ("emoji_events", "Celebrar un logro", "Celebrate a milestone"),
        ("military_tech", "Ganar una insignia", "Earn a badge"),
        ("flag", "Fijar una meta", "Set a goal"),
    ]

    @Test("cada ícono se anuncia con el texto de Android en español y en inglés", arguments: androidTable)
    func iconLabel(key: String, spanish: String, english: String) {
        #expect(Self.resolve(HabitIcons.label(for: key), Self.spanish) == spanish)
        #expect(Self.resolve(HabitIcons.label(for: key), Self.english) == english)
    }

    /// The table above is only proof if it covers the picker exactly: a new icon added to
    /// `HabitIcons.categories` without a label has to fail here, not read "Ícono" in production.
    @Test("la tabla cubre exactamente los íconos del selector")
    func tableCoversEveryPickerKey() {
        #expect(Self.androidTable.count == HabitIcons.allKeys.count)
        #expect(Set(Self.androidTable.map { $0.0 }) == Set(HabitIcons.allKeys))
    }

    @Test("ningún ícono cae en la etiqueta genérica", arguments: [spanish, english])
    func noIconUsesTheFallback(locale: Locale) {
        let fallback = Self.resolve(HabitIcons.label(for: "no_such_icon"), locale)
        for key in HabitIcons.allKeys {
            #expect(Self.resolve(HabitIcons.label(for: key), locale) != fallback, "\(key)")
        }
    }

    /// Two icons with the same name are two indistinguishable buttons to a VoiceOver user.
    @Test("dos íconos nunca se anuncian igual", arguments: [spanish, english])
    func labelsAreDistinct(locale: Locale) {
        let labels = HabitIcons.allKeys.map { Self.resolve(HabitIcons.label(for: $0), locale) }
        let repeated = Dictionary(grouping: labels, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(repeated.isEmpty, "\(repeated.sorted())")
    }

    @Test("una clave desconocida se anuncia como «Ícono»")
    func unknownKeyFallback() {
        #expect(Self.resolve(HabitIcons.label(for: "no_such_icon"), Self.spanish) == "Ícono")
        #expect(Self.resolve(HabitIcons.label(for: "no_such_icon"), Self.english) == "Icon")
    }

    /// Habits created from a template before the key fix still carry an SF Symbol name.
    @Test("una clave vieja se anuncia como su clave estable", arguments: HabitIconAliases.legacyToStable.map { ($0.key, $0.value) })
    func legacyKeyLabel(legacy: String, stable: String) {
        #expect(Self.resolve(HabitIcons.label(for: legacy), Self.spanish)
                == Self.resolve(HabitIcons.label(for: stable), Self.spanish))
    }

    // MARK: - Colours

    @Test("cada color se anuncia con su número, como en Android", arguments: HabitPalette.colors.indices)
    func colourLabel(index: Int) {
        #expect(Self.resolve(HabitPalette.accessibilityLabel(at: index), Self.spanish) == "Color \(index + 1)")
        #expect(Self.resolve(HabitPalette.accessibilityLabel(at: index), Self.english) == "Color \(index + 1)")
    }

    // MARK: - Heatmap

    @Test(
        "el valor del mapa de actividad usa singular y plural",
        arguments: [
            (0, "0 días completados", "0 days completed"),
            (1, "1 día completado", "1 day completed"),
            (2, "2 días completados", "2 days completed"),
            (182, "182 días completados", "182 days completed"),
        ]
    )
    func heatmapValue(count: Int, spanish: String, english: String) {
        #expect(Self.resolve(LocalizedStringResource("\(count) días completados"), Self.spanish) == spanish)
        #expect(Self.resolve(LocalizedStringResource("\(count) días completados"), Self.english) == english)
    }
}

/// The number VoiceOver reads for the heatmap has to be the number of accent-coloured cells.
@Suite("Días completados del mapa de actividad")
struct HeatmapCompletedDayCountTests {

    private let calendar = TestCalendar.fixed
    private let today = TestCalendar.today
    private let weeks = 26

    /// First day the grid draws, in the same calendar the count uses.
    private var gridStart: Date {
        calendar.startOfDay(for: HeatmapGrid.gridStart(today: calendar.startOfDay(for: today), weeks: weeks))
    }

    private func offset(of date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: date).day!
    }

    private func count(_ offsets: [Int], start: Int = -400, end: Int? = nil) -> Int {
        HabitHeatmapView.completedDayCount(
            completions: Set(offsets.map { TestCalendar.day($0) }),
            today: today,
            weeks: weeks,
            startDate: TestCalendar.day(start),
            endDate: end.map { TestCalendar.day($0) },
            calendar: calendar
        )
    }

    @Test("sin marcas, cero")
    func empty() {
        #expect(count([]) == 0)
    }

    @Test("hoy cuenta y mañana no")
    func todayCountsFutureDoesNot() {
        #expect(count([0, -1, 1, 5]) == 2)
    }

    @Test("el primer día de la grilla cuenta y el anterior no")
    func gridStartBoundary() {
        let first = offset(of: gridStart)
        #expect(count([first, first - 1]) == 1)
    }

    @Test("los días antes del inicio del hábito no cuentan")
    func beforeStartDate() {
        #expect(count([-10, -9, -8], start: -9) == 2)
    }

    @Test("los días después de la fecha de fin no cuentan")
    func afterEndDate() {
        #expect(count([-10, -5, -4, -1], end: -5) == 2)
    }

    @Test("un hábito que termina antes de la grilla no cuenta nada")
    func endBeforeGrid() {
        let first = offset(of: gridStart)
        #expect(count([first - 3, first - 2], start: first - 10, end: first - 2) == 0)
    }

    @Test("dos marcas del mismo día a distinta hora cuentan una vez")
    func sameDayTwice() {
        let completions: Set<Date> = [TestCalendar.day(-2, hour: 8), TestCalendar.day(-2, hour: 21)]
        let result = HabitHeatmapView.completedDayCount(
            completions: completions, today: today, weeks: weeks,
            startDate: TestCalendar.day(-30), endDate: nil, calendar: calendar
        )
        #expect(result == 1)
    }
}
