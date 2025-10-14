import SwiftUI

struct RestaurantCard: View {
    let name: String
    let category: String
    let tag: String
    let rating: Double
    let imageURL: String       
    var panelColor: Color = Palette.purpleLight

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                StarsView(rating: rating)

                Text(name)
                    .font(.custom("Montserrat-SemiBold", size: 18))
                    .foregroundColor(.white)

                Text(category)
                    .font(.custom("Montserrat-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.95))

                if !tag.isEmpty {
                    Text(tag)
                        .font(.custom("Montserrat-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelColor)

            RemoteImage(urlString: imageURL)
                .frame(width: 140, height: 128)
                .clipped()
        }
        .frame(height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}
