import SwiftUI

struct OfferCard: View {
    let title: String
    let description: String
    let imageURL: String
    let price: Int
    var trailingEdit: (() -> Void)? = nil
    var panelColor: Color = Palette.purpleLight

    private var priceText: String {
        if price <= 0 { return "" }
        return "$\(price)"
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 18))
                    .foregroundStyle(.white)

                if !priceText.isEmpty {
                    Text(priceText)
                        .font(.custom("Montserrat-Bold", size: 16))
                        .foregroundStyle(.white.opacity(0.95))
                }

                Text(description)
                    .font(.custom("Montserrat-Regular", size: 15))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelColor)

            ZStack(alignment: .topTrailing) {
                RemoteImage(urlString: imageURL)
                    .frame(width: 160, height: 140)
                    .clipped()

                if let trailingEdit {
                    Button("Edit", action: trailingEdit)
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}
