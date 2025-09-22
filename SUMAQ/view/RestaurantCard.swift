import SwiftUI

struct RestaurantCard: View {
    let name: String
    let category: String
    let tag: String
    let rating: Double
    let image: Image

    private let purple = Palette.purple

    var body: some View {
        HStack(spacing: 0) {
            // Panel morado (texto + estrellas)
            VStack(alignment: .leading, spacing: 10) {
                StarsView(rating: rating)

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(category)
                        .font(.custom("Montserrat-Regular", size: 15))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Text(tag)
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(purple)

            // Imagen
            image
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 124)
                .clipped()
                .background(Color.white)
        }
        .frame(height: 140) // ⬅️ igual que OfferCard
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}
