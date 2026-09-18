import Foundation
import Testing
@testable import quoteAnime

/// What the paywall prints for a plan. Nothing here is hardcoded in the app — the price arrives
/// already formatted by the store — so what is worth pinning is the period wording (Android shows
/// the raw `"P1M"`) and the free-trial line.
@Suite("Ofertas de suscripción")
struct SubscriptionOfferTests {

    private static let spanish = Locale(identifier: "es")
    private static let english = Locale(identifier: "en")

    private static func resolve(_ text: String.LocalizationValue, _ locale: Locale) -> String {
        String(localized: LocalizedStringResource(text, locale: locale))
    }

    // MARK: - Period

    @Test(
        "un plan de un período se lee en singular",
        arguments: [
            (SubscriptionOffer.PeriodUnit.day, "cada día", "every day"),
            (.week, "cada semana", "every week"),
            (.month, "cada mes", "every month"),
            (.year, "cada año", "every year"),
        ]
    )
    func singularPeriod(unit: SubscriptionOffer.PeriodUnit, spanish: String, english: String) {
        let value = 1
        let key: String.LocalizationValue
        switch unit {
        case .day:   key = "cada \(value) días"
        case .week:  key = "cada \(value) semanas"
        case .month: key = "cada \(value) meses"
        case .year:  key = "cada \(value) años"
        }
        #expect(Self.resolve(key, Self.spanish) == spanish)
        #expect(Self.resolve(key, Self.english) == english)
    }

    @Test(
        "un plan de varios períodos se lee en plural",
        arguments: [
            (SubscriptionOffer.PeriodUnit.month, 3, "cada 3 meses", "every 3 months"),
            (.year, 2, "cada 2 años", "every 2 years"),
            (.week, 2, "cada 2 semanas", "every 2 weeks"),
            (.day, 10, "cada 10 días", "every 10 days"),
        ]
    )
    func pluralPeriod(unit: SubscriptionOffer.PeriodUnit, value: Int, spanish: String, english: String) {
        let key: String.LocalizationValue
        switch unit {
        case .day:   key = "cada \(value) días"
        case .week:  key = "cada \(value) semanas"
        case .month: key = "cada \(value) meses"
        case .year:  key = "cada \(value) años"
        }
        #expect(Self.resolve(key, Self.spanish) == spanish)
        #expect(Self.resolve(key, Self.english) == english)
    }

    @Test("el precio va con su período, sin reformatear lo que dio la tienda")
    func priceKeepsTheStoreFormatting() {
        let offer = SubscriptionOfferFixture.make(formattedPrice: "S/ 19.90", periodUnit: .month, periodValue: 1)

        #expect(offer.priceDescription.contains("S/ 19.90"))
        #expect(offer.priceDescription == "S/ 19.90 \(offer.periodDescription)")
    }

    // MARK: - Free trial

    @Test("sin prueba gratis no hay línea de prueba")
    func noTrialMeansNoLine() {
        #expect(SubscriptionOfferFixture.make(freeTrialDays: nil).freeTrialDescription == nil)
    }

    @Test("la prueba gratis se lee en singular y plural",
          arguments: [(1, "1 día de prueba gratis"), (7, "7 días de prueba gratis")])
    func trialLine(days: Int, spanish: String) {
        #expect(Self.resolve("\(days) días de prueba gratis", Self.spanish) == spanish)
        #expect(SubscriptionOfferFixture.make(freeTrialDays: days).freeTrialDescription != nil)
    }

    @Test(
        "los días de prueba salen del período introductorio, como en Android",
        arguments: [
            (SubscriptionOffer.PeriodUnit.day, 3, 3),
            (.week, 1, 7),
            (.week, 2, 14),
            (.month, 1, 30),
            (.year, 1, 365),
        ]
    )
    func trialDaysFromPeriod(unit: SubscriptionOffer.PeriodUnit, value: Int, expected: Int) {
        #expect(PremiumOfferMapper.trialDays(unit: unit, value: value) == expected)
    }
}
