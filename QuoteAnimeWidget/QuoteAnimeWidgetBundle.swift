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
        QuoteAnimeWidgetControl()
        QuoteAnimeWidgetLiveActivity()
    }
}
