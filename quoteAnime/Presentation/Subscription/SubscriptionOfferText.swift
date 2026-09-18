import Foundation

extension SubscriptionOffer {
    /// "cada mes", "cada 3 meses". Android puts the store's raw ISO-8601 period on screen
    /// (`"P1M"`); iOS spells it out and lets the catalog pick the singular or the plural.
    var periodDescription: String {
        switch periodUnit {
        case .day:   return String(localized: "cada \(periodValue) días")
        case .week:  return String(localized: "cada \(periodValue) semanas")
        case .month: return String(localized: "cada \(periodValue) meses")
        case .year:  return String(localized: "cada \(periodValue) años")
        }
    }

    /// `nil` when the plan has no introductory free trial, so the UI can leave the row out.
    var freeTrialDescription: String? {
        guard let freeTrialDays else { return nil }
        return String(localized: "\(freeTrialDays) días de prueba gratis")
    }

    /// The whole line: price plus period, in the user's locale — "4,99 € cada mes".
    var priceDescription: String {
        "\(formattedPrice) \(periodDescription)"
    }
}
