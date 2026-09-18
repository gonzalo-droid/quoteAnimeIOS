import Foundation
import Testing
@testable import quoteAnime

/// The paywall's own logic: which state it lands in, and what it tells the user afterwards.
@Suite("PaywallViewModel")
@MainActor
struct PaywallViewModelTests {

    private static func makeSUT(
        premium: Bool = false,
        offers: [SubscriptionOffer] = [SubscriptionOfferFixture.make()]
    ) -> (PaywallViewModel, FakePremiumStore, FakeEntitlementSource) {
        let source = FakeEntitlementSource(isPremium: premium)
        let store = FakePremiumStore()
        store.offers = offers
        store.entitlementSource = source
        let viewModel = PaywallViewModel(premiumGate: PremiumGate(source: source), store: store)
        return (viewModel, store, source)
    }

    // MARK: - Offers

    @Test("con planes en la tienda se muestran y se preselecciona el primero")
    func loadsOffers() async {
        let monthly = SubscriptionOfferFixture.make(id: "mensual", periodUnit: .month)
        let yearly = SubscriptionOfferFixture.make(id: "anual", periodUnit: .year)
        let (viewModel, _, _) = Self.makeSUT(offers: [monthly, yearly])

        await viewModel.loadOffers()

        #expect(viewModel.uiState.offers.count == 2)
        #expect(viewModel.uiState.selectedOffer?.id == "mensual")
        #expect(viewModel.uiState.offersUnavailable == false)
        #expect(viewModel.uiState.canSubscribe)
    }

    @Test("sin planes se muestra el estado vacío y no se puede suscribir")
    func emptyOffersShowTheEmptyState() async {
        let (viewModel, _, _) = Self.makeSUT(offers: [])

        await viewModel.loadOffers()

        #expect(viewModel.uiState.offersUnavailable)
        #expect(viewModel.uiState.canSubscribe == false)
        #expect(viewModel.uiState.selectedOffer == nil)
    }

    @Test("mientras se cargan los planes no hay estado vacío")
    func loadingIsNotEmpty() {
        let (viewModel, _, _) = Self.makeSUT(offers: [])

        #expect(viewModel.uiState.isLoadingOffers)
        #expect(viewModel.uiState.offersUnavailable == false)
    }

    @Test("se puede elegir otro plan")
    func selectingAnotherOffer() async {
        let monthly = SubscriptionOfferFixture.make(id: "mensual")
        let yearly = SubscriptionOfferFixture.make(id: "anual", periodUnit: .year)
        let (viewModel, _, _) = Self.makeSUT(offers: [monthly, yearly])
        await viewModel.loadOffers()

        viewModel.selectOffer(yearly)

        #expect(viewModel.uiState.selectedOffer?.id == "anual")
    }

    // MARK: - Purchase

    @Test("una compra correcta deja premium y no muestra mensaje")
    func successfulPurchase() async {
        let (viewModel, store, _) = Self.makeSUT()
        await viewModel.loadOffers()

        await viewModel.subscribe()

        #expect(store.purchasedOffers.count == 1)
        #expect(viewModel.uiState.message == nil)
        #expect(viewModel.uiState.isPremium)
        #expect(viewModel.uiState.isPurchasing == false)
    }

    @Test(
        "cada fallo de compra tiene su propio mensaje",
        arguments: [
            (PremiumPurchaseOutcome.cancelled, PaywallMessage.purchaseCancelled),
            (.pending, .purchasePending),
            (.failed(.network), .network),
            (.failed(.storeUnavailable), .storeUnavailable),
            (.failed(.unverified), .purchaseUnverified),
            (.failed(.unknown), .purchaseFailed),
        ]
    )
    func purchaseOutcomeMessages(outcome: PremiumPurchaseOutcome, expected: PaywallMessage) async {
        let (viewModel, store, _) = Self.makeSUT()
        store.purchaseOutcome = outcome
        await viewModel.loadOffers()

        await viewModel.subscribe()

        #expect(viewModel.uiState.message == expected)
        #expect(viewModel.uiState.isPremium == false)
    }

    @Test("sin plan elegido el botón no compra nada")
    func noOfferMeansNoPurchase() async {
        let (viewModel, store, _) = Self.makeSUT(offers: [])
        await viewModel.loadOffers()

        await viewModel.subscribe()

        #expect(store.purchasedOffers.isEmpty)
    }

    @Test("el mensaje se descarta al tocarlo")
    func messageIsDismissable() async {
        let (viewModel, store, _) = Self.makeSUT()
        store.purchaseOutcome = .cancelled
        await viewModel.loadOffers()
        await viewModel.subscribe()

        viewModel.onMessageShown()

        #expect(viewModel.uiState.message == nil)
    }

    // MARK: - Restore

    @Test("restaurar con una compra previa devuelve premium")
    func restoreFindsAPurchase() async {
        let (viewModel, store, _) = Self.makeSUT()
        store.restoreOutcome = .restored

        await viewModel.restorePurchases()

        #expect(viewModel.uiState.message == .restored)
        #expect(viewModel.uiState.isPremium)
    }

    @Test("restaurar sin compras lo dice en vez de quedarse callado")
    func restoreFindsNothing() async {
        let (viewModel, store, _) = Self.makeSUT()
        store.restoreOutcome = .nothingToRestore

        await viewModel.restorePurchases()

        #expect(viewModel.uiState.message == .nothingToRestore)
        #expect(viewModel.uiState.isPremium == false)
    }

    @Test("un fallo al restaurar se reporta con su motivo")
    func restoreFails() async {
        let (viewModel, store, _) = Self.makeSUT()
        store.restoreOutcome = .failed(.network)

        await viewModel.restorePurchases()

        #expect(viewModel.uiState.message == .network)
    }

    // MARK: - Changes that happen outside the app

    @Test("si la tienda retira el entitlement el paywall vuelve a ofrecer la compra")
    func entitlementRevokedOutsideTheApp() async throws {
        let (viewModel, _, source) = Self.makeSUT(premium: true)
        #expect(viewModel.uiState.isPremium)

        source.set(false)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.uiState.isPremium == false)
    }

    // MARK: - Retention sheet

    @Test("gestionar la suscripción abre primero la hoja de retención")
    func manageOpensRetentionSheet() {
        let (viewModel, _, _) = Self.makeSUT(premium: true)

        viewModel.onManageSubscriptionTapped()

        #expect(viewModel.isShowingCancelSheet)
    }

    @Test("seguir siendo premium sólo cierra la hoja")
    func keepPremiumJustCloses() {
        let (viewModel, _, _) = Self.makeSUT(premium: true)
        viewModel.onManageSubscriptionTapped()

        viewModel.onKeepPremium()

        #expect(viewModel.isShowingCancelSheet == false)
        #expect(viewModel.uiState.isPremium)
    }
}
