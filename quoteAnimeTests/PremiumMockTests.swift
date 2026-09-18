import Foundation
import Testing
@testable import quoteAnime

/// Premium while `PremiumConfig.usesRealBilling` is `false`: the App Store sees "Próximamente"
/// and the free limits, DEBUG and TestFlight get a switch that grants premium locally, and
/// StoreKit is never built nor asked anything.
@Suite("Premium en mock")
@MainActor
struct PremiumMockTests {

    // MARK: - Helpers

    /// Factories that record a test failure if the composition ever calls them.
    private static func failingStoreKitSource() -> PremiumEntitlementSource {
        Issue.record("StoreKitEntitlementSource no debe construirse con el interruptor en false")
        return FakeEntitlementSource()
    }

    private static func failingStoreKitStore(_ source: PremiumEntitlementSource) -> PremiumStore {
        Issue.record("StoreKitPremiumStore no debe construirse con el interruptor en false")
        return FakePremiumStore()
    }

    private static func mockServices(
        _ detector: FakeDistributionDetector,
        defaults: UserDefaults
    ) -> PremiumServices {
        PremiumServices.make(
            usesRealBilling: false,
            defaults: defaults,
            detector: detector,
            makeStoreKitSource: failingStoreKitSource,
            makeStoreKitStore: failingStoreKitStore
        )
    }

    private static func paywall(
        _ services: PremiumServices,
        store: FakePremiumStore = FakePremiumStore()
    ) -> PaywallViewModel {
        PaywallViewModel(
            premiumGate: services.gate,
            store: store,
            purchaseAvailability: services.purchaseAvailability,
            testControls: services.testControls
        )
    }

    // MARK: - The switch

    @Test("DIVERGENCIA: premium es un mock hasta la versión productiva (Android ya cobra con Play Billing)")
    func switchIsOffUntilProduction() {
        #expect(PremiumConfig.usesRealBilling == false)
        #expect(PremiumServices.live.purchaseAvailability == .comingSoon)
        #expect(PremiumServices.live.store is UnavailablePremiumStore)
    }

    // MARK: - Distribution

    @Test(
        "de dónde viene el binario decide si hay premium de prueba",
        arguments: [
            (true, StoreEnvironment?.some(.production), true, AppDistribution?.some(.debug)),
            (true, nil, true, .some(.debug)),
            (false, .some(.sandbox), true, .some(.testFlight)),
            (false, .some(.production), true, .some(.appStore)),
            (false, .some(.xcode), true, .some(.appStore)),
            (false, .some(.other), true, .some(.appStore)),
            (false, .some(.sandbox), false, .some(.appStore)),
            (false, nil, true, nil),
        ]
    )
    func resolvesDistribution(
        isDebugBuild: Bool,
        environment: StoreEnvironment?,
        isVerified: Bool,
        expected: AppDistribution?
    ) {
        #expect(
            AppDistribution.resolve(
                isDebugBuild: isDebugBuild,
                environment: environment,
                isVerified: isVerified
            ) == expected
        )
    }

    @Test("sólo la App Store queda fuera del premium de prueba")
    func onlyAppStoreForbidsTestPremium() {
        #expect(AppDistribution.debug.allowsTestPremium)
        #expect(AppDistribution.testFlight.allowsTestPremium)
        #expect(AppDistribution.appStore.allowsTestPremium == false)
    }

    // MARK: - StoreKit stays asleep

    @Test("con el interruptor en false StoreKit no se construye ni se consulta")
    func storeKitIsNeverBuiltNorAsked() async {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let store = FakePremiumStore()
        let services = Self.mockServices(.known(.appStore), defaults: testDefaults.defaults)
        let viewModel = Self.paywall(services, store: store)

        await services.gate.refresh()
        viewModel.onAppear()
        await viewModel.loadOffers()
        await viewModel.subscribe()
        await viewModel.restorePurchases()
        viewModel.onManageSubscriptionTapped()

        #expect(services.purchaseAvailability == .comingSoon)
        #expect(services.store is UnavailablePremiumStore)
        #expect(services.gate.source is MockPremiumEntitlementSource)
        #expect(store.loadOffersCount == 0)
        #expect(store.purchasedOffers.isEmpty)
        #expect(store.restoreCount == 0)
    }

    @Test("el store de reemplazo no vende nada si alguien lo llama")
    func unavailableStoreSellsNothing() async {
        let store = UnavailablePremiumStore()

        #expect(await store.loadOffers().isEmpty)
        #expect(await store.purchase(SubscriptionOfferFixture.make()) == .failed(.storeUnavailable))
        #expect(await store.restore() == .nothingToRestore)
    }

    // MARK: - App Store

    @Test("en la App Store el paywall dice Próximamente y el botón no compra")
    func appStorePaywallIsComingSoon() async {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let store = FakePremiumStore()
        store.offers = [SubscriptionOfferFixture.make()]
        let viewModel = Self.paywall(
            Self.mockServices(.known(.appStore), defaults: testDefaults.defaults),
            store: store
        )

        viewModel.onAppear()
        await viewModel.subscribe()

        #expect(viewModel.uiState.isComingSoon)
        #expect(viewModel.uiState.canSubscribe == false)
        #expect(viewModel.uiState.isLoadingOffers == false)
        #expect(viewModel.uiState.offersUnavailable == false)
        #expect(store.purchasedOffers.isEmpty)
        #expect(viewModel.uiState.isPremium == false)
    }

    @Test("en la App Store no hay restaurar ni gestionar suscripción")
    func appStoreHasNoRestoreNorManage() async {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let store = FakePremiumStore()
        let viewModel = Self.paywall(
            Self.mockServices(.known(.appStore), defaults: testDefaults.defaults),
            store: store
        )

        await viewModel.restorePurchases()
        viewModel.onManageSubscriptionTapped()

        #expect(viewModel.uiState.showsRestore == false)
        #expect(viewModel.uiState.showsManageSubscription == false)
        #expect(store.restoreCount == 0)
        #expect(viewModel.isShowingCancelSheet == false)
        #expect(viewModel.uiState.message == nil)
    }

    @Test("en la App Store el flag del mock en true no da premium")
    func appStoreIgnoresTheMockFlag() async {
        let testDefaults = TestDefaults(premiumFlag: true)
        defer { testDefaults.tearDown() }
        let services = Self.mockServices(.known(.appStore), defaults: testDefaults.defaults)

        await services.gate.refresh()

        #expect(services.gate.isPremium == false)
        #expect(services.gate.maxActiveHabits == PremiumGate.freeHabitLimit)
        #expect(Self.paywall(services).uiState.isPremium == false)
    }

    @Test("en la App Store no aparece el botón de prueba y llamarlo no hace nada")
    func appStoreRejectsTheTestSwitch() {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let services = Self.mockServices(.known(.appStore), defaults: testDefaults.defaults)
        let viewModel = Self.paywall(services)

        viewModel.setTestPremium(true)
        services.testControls?.setTestPremium(true)

        #expect(viewModel.uiState.canUseTestPremium == false)
        #expect(services.gate.isPremium == false)
        #expect(viewModel.uiState.isPremium == false)
        #expect(testDefaults.defaults.object(forKey: MockPremiumEntitlementSource.flagKey) == nil)
    }

    @Test("en la App Store los tres gates siguen en gratuito")
    func appStoreKeepsTheFreeLimits() async throws {
        let testDefaults = TestDefaults(premiumFlag: true)
        defer { testDefaults.tearDown() }
        let gate = Self.mockServices(.known(.appStore), defaults: testDefaults.defaults).gate
        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(PremiumGate.freeHabitLimit))
        let createHabit = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached(max: PremiumGate.freeHabitLimit)) {
            try await createHabit.execute(HabitFixture.make(id: "cuarto"))
        }
        let locked = DefaultHabitTemplates.all.filter { $0.isLocked(isPremium: gate.isPremium) }
        #expect(Set(locked.map(\.id)) == ["theme_pokemon", "theme_black_clover"])
        var ads = ShareAdPolicy()
        let shares = (1...3).map { _ in ads.shouldShowAd(isPremium: gate.isPremium) }
        #expect(shares == [false, false, true])
    }

    // MARK: - Debug and TestFlight

    @Test(
        "en debug y TestFlight el mock activa y desactiva premium y los tres gates responden",
        arguments: [AppDistribution.debug, .testFlight]
    )
    func testPremiumDrivesTheGates(distribution: AppDistribution) async throws {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let services = Self.mockServices(.known(distribution), defaults: testDefaults.defaults)
        await services.gate.refresh()
        let viewModel = Self.paywall(services)
        let gate = services.gate
        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(PremiumGate.freeHabitLimit))
        let createHabit = CreateHabitUseCase(repository: repository, premiumGate: gate)

        #expect(viewModel.uiState.canUseTestPremium)
        #expect(viewModel.uiState.isComingSoon)
        #expect(gate.isPremium == false)

        // On.
        viewModel.setTestPremium(true)

        #expect(gate.isPremium)
        #expect(viewModel.uiState.isPremium)
        #expect(viewModel.uiState.showsManageSubscription == false)
        try await createHabit.execute(HabitFixture.make(id: "cuarto"))
        #expect(try await repository.countActiveHabits() == PremiumGate.freeHabitLimit + 1)
        #expect(DefaultHabitTemplates.all.allSatisfy { !$0.isLocked(isPremium: gate.isPremium) })
        var ads = ShareAdPolicy()
        #expect((1...6).allSatisfy { _ in !ads.shouldShowAd(isPremium: gate.isPremium) })

        // Off again: blocks the next creation, keeps the habit already made.
        viewModel.setTestPremium(false)

        #expect(gate.isPremium == false)
        #expect(viewModel.uiState.isPremium == false)
        await #expect(throws: CreateHabitError.habitLimitReached(max: PremiumGate.freeHabitLimit)) {
            try await createHabit.execute(HabitFixture.make(id: "quinto"))
        }
        #expect(try await repository.countActiveHabits() == PremiumGate.freeHabitLimit + 1)
        #expect(DefaultHabitTemplates.all.contains { $0.isLocked(isPremium: gate.isPremium) })
        #expect(ads.shouldShowAd(isPremium: gate.isPremium) == false)
    }

    @Test("el premium de prueba sobrevive a reabrir la app", arguments: [AppDistribution.debug, .testFlight])
    func testPremiumPersists(distribution: AppDistribution) async {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        Self.mockServices(.known(distribution), defaults: testDefaults.defaults)
            .testControls?.setTestPremium(true)

        let relaunched = Self.mockServices(.known(distribution), defaults: testDefaults.defaults)
        await relaunched.gate.refresh()

        #expect(relaunched.gate.isPremium)
    }

    // MARK: - A release build before it knows where it runs

    @Test("un build de release trata la instalación como App Store hasta saber que es TestFlight")
    func releaseFailsClosedUntilDetected() async {
        let testDefaults = TestDefaults(premiumFlag: true)
        defer { testDefaults.tearDown() }
        let detector = FakeDistributionDetector(provisional: .appStore, detected: .testFlight)
        let services = Self.mockServices(detector, defaults: testDefaults.defaults)
        let viewModel = Self.paywall(services)

        #expect(services.gate.isPremium == false)
        #expect(viewModel.uiState.canUseTestPremium == false)

        await services.gate.refresh()
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(services.gate.isPremium)
        #expect(viewModel.uiState.canUseTestPremium)
        #expect(viewModel.uiState.isPremium)
    }

    @Test("si no se pudo averiguar el entorno sigue como App Store y reintenta al volver")
    func unknownDistributionRetries() async {
        let testDefaults = TestDefaults(premiumFlag: true)
        defer { testDefaults.tearDown() }
        let detector = FakeDistributionDetector(provisional: .appStore, detected: nil)
        let services = Self.mockServices(detector, defaults: testDefaults.defaults)

        await services.gate.refresh()
        #expect(services.gate.isPremium == false)
        #expect(services.testControls?.isTestPremiumAvailable == false)

        detector.detected = .testFlight
        await services.gate.refresh()
        #expect(services.gate.isPremium)

        await services.gate.refresh()
        await services.gate.refresh()
        #expect(detector.detectCount == 2)
    }

    // MARK: - The switch on

    @Test("con el interruptor en true se construye StoreKit una vez y el store comparte la fuente del gate")
    func realBillingBuildsStoreKitOnce() async {
        let testDefaults = TestDefaults()
        defer { testDefaults.tearDown() }
        let storeKit = FakeEntitlementSource()
        var sourcesBuilt = 0
        var storeSource: PremiumEntitlementSource?

        let services = PremiumServices.make(
            usesRealBilling: true,
            defaults: testDefaults.defaults,
            detector: FakeDistributionDetector(),
            makeStoreKitSource: {
                sourcesBuilt += 1
                return storeKit
            },
            makeStoreKitStore: { source in
                storeSource = source
                return FakePremiumStore()
            }
        )
        await services.gate.refresh()

        #expect(sourcesBuilt == 1)
        #expect(storeSource === services.gate.source)
        #expect(services.purchaseAvailability == .store)
        #expect(storeKit.refreshCount == 1)
        #expect(Self.paywall(services).uiState.isComingSoon == false)
        #expect(Self.paywall(services).uiState.showsRestore)
    }
}
