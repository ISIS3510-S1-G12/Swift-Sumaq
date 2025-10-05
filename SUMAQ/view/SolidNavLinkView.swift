import SwiftUI

struct SolidNavLink<Destination: View>: View {
    let title: String
    let color: Color
    let textColor: Color
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
                .toolbar(.hidden, for: .navigationBar)
        } label: {
            Text(title)
                .font(.custom("Mukta-Bold", size: 18))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .clipShape(Capsule())
                .shadow(radius: 2, y: 1)
            
            
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
