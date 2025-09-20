// FilterBar.swift (versión internal)

import SwiftUI

struct FilterBarConfig {
    var searchColor:   Color   = Palette.orange
    var ringColor:     Color   = Palette.orange
    var diameter:      CGFloat = 44
    var ringLineWidth: CGFloat = 2
}

struct FilterBar<Option: CaseIterable & Identifiable & Hashable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var text: String
    @Binding var selectedFilter: Option?

    var config: FilterBarConfig = .init()
    var options: [Option] = Array(Option.allCases)

    init(
        text: Binding<String>,
        selectedFilter: Binding<Option?>,
        config: FilterBarConfig = .init(),
        options: [Option] = Array(Option.allCases)
    ) {
        self._text = text
        self._selectedFilter = selectedFilter
        self.config = config
        self.options = options
    }

    var body: some View {
        HStack(spacing: 10) {
            SearchBar(text: $text, color: config.searchColor)

            Menu {
                Text("Filter by")
                    .font(.custom("Montserrat-SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)

                ForEach(options) { option in
                    Button {
                        selectedFilter = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selectedFilter == option { Image(systemName: "checkmark") }
                        }
                    }
                }

                if selectedFilter != nil {
                    Divider()
                    Button("Clear filter", role: .destructive) { selectedFilter = nil }
                }
            } label: {
                _RoundIconLabel(
                    systemName: "line.3.horizontal.decrease",
                    diameter: config.diameter,
                    ringLineWidth: config.ringLineWidth,
                    color: config.ringColor
                )
                .accessibilityLabel("Filter")
            }
            .menuOrder(.fixed)
        }
    }
}

private struct _RoundIconLabel: View {
    let systemName: String
    let diameter: CGFloat
    let ringLineWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: ringLineWidth)
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.45, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }
}
