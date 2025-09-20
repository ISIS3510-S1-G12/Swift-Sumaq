import SwiftUI

struct OfferCard: View {
    let title: String
    let description: String
    let rating: Double
    let image: Image             // <- ahora siempre recibe Image

    private let purple = Palette.purpleLight

    var body: some View {
        HStack(spacing: 0) {
            // Panel morado
            VStack(alignment: .leading, spacing: 10) {
                StarsView(rating: rating)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.custom("Montserrat-Regular", size: 15))
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(purple)

            // Imagen de la oferta
            image
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 124)
                .clipped()
                .background(Color.white)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}
