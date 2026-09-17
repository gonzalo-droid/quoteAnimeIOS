//
//  QuoteAnimeWidgetBundle.swift
//  QuoteAnimeWidget
//
//  Created by Gonzalo on 7/04/26.
//

import WidgetKit
import SwiftUI

@main
struct QuoteAnimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuoteAnimeWidget()
        QuoteAnimeLockWidget()
        RoutineSummaryWidget()
        // iOS 17+ only: `AppIntentConfiguration` (the native habit picker in the widget's edit
        // sheet) doesn't exist on iOS 16. The members above keep working on 16.6.
        if #available(iOS 17.0, *) {
            HabitWidget()
        }
    }
}
