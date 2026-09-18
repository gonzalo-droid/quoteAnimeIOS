import Foundation

/// The one switch between the premium mock and real App Store billing.
enum PremiumConfig {
    /// `false`: premium is a mock. Nothing talks to the App Store — no products are loaded, no
    /// `Transaction.updates` listener runs, nothing re-syncs on returning to the foreground. The
    /// paywall shows the benefits with a disabled "Próximamente" button and no restore or manage;
    /// the free limits still apply. DEBUG and TestFlight builds get a "(solo pruebas)" switch that
    /// grants premium locally; App Store builds never honour it.
    ///
    /// `true`: StoreKit 2, exactly as shipped in tanda 7 (`StoreKitEntitlementSource`,
    /// `StoreKitPremiumStore`, restore, manage, the retention sheet, the DEBUG-only QA override).
    ///
    /// Before flipping this to `true`, all of these must be done:
    /// 1. **App Store Connect** — an auto-renewable subscription with product id
    ///    `premium_subscription` (`PremiumProducts.subscriptionId`) in a subscription group,
    ///    with its price, localized display name and description, and its review screenshot.
    ///    Status "Ready to Submit", attached to the app version that ships the switch.
    /// 2. **Agreements, Tax, and Banking** — the Paid Apps agreement active, with tax and bank
    ///    information complete. Without it the store returns no products and the paywall shows
    ///    "planes no disponibles".
    /// 3. **Sandbox test** — a sandbox Apple Account on a real device, running a TestFlight or
    ///    development build with this set to `true`: buy, cancel from Settings and see premium
    ///    go, restore on a second install, and the manage-subscription sheet. The local
    ///    `quoteAnimeTests/Premium.storekit` (Xcode only) is not a substitute: it never touches
    ///    App Store Connect.
    /// 4. **Docs** — `PARITY.md` (the "Premium en mock" divergence), `CLAUDE.md` and `CHANGELOG.md`.
    static let usesRealBilling = false
}
