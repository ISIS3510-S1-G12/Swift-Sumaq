//
//  ScreenTrackerModifier.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import SwiftUI

struct ScreenTracker: ViewModifier {
    let name: String
    var extra: [String: Any] = [:]

    @State private var didStart = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didStart else { return }
                didStart = true
                AnalyticsService.shared.screenStart(name, extra: extra)
            }
            .onDisappear {
                guard didStart else { return }
                didStart = false
                AnalyticsService.shared.screenEnd(name, extra: extra)
            }
    }
}

extension View {
    func trackScreen(_ name: String, extra: [String: Any] = [:]) -> some View {
        self.modifier(ScreenTracker(name: name, extra: extra))
    }
}
