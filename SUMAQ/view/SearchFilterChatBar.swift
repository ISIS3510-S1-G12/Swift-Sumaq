import SwiftUI


struct SearchFilterChatBar<Option: CaseIterable & Identifiable & Hashable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var text: String
    @Binding var selectedFilter: Option?
    var onChatTap: () -> Void = {}

    var config: FilterBarConfig = .init()

    var options: [Option] = Array(Option.allCases)

    var body: some View {
        HStack(spacing: 10) {
            FilterBar<Option>(
                text: $text,
                selectedFilter: $selectedFilter,
                config: config,
                options: options
            )

            Button(action: onChatTap) {
                RoundIconLabel(
                    systemName: "bubble.right",
                    diameter: config.diameter,
                    ringLineWidth: config.ringLineWidth,
                    color: config.ringColor
                )
                .accessibilityLabel("Chat")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RoundIconLabel: View {
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
