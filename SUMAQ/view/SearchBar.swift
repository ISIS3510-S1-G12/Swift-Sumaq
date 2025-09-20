import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var color: Color = Palette.orangeAlt

    var body: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $text,
                prompt: Text("Search")
                    .foregroundStyle(.white.opacity(0.95))
                    .font(.custom("Montserrat-SemiBold", size: 18, relativeTo: .headline))
            )
            .textInputAutocapitalization(.never)
            .foregroundStyle(.white)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color)
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
}
