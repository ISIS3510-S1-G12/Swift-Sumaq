import SwiftUI

struct OfferCard: View {
    let title: String
    let description: String
    let imageURL: String
    var trailingEdit: (() -> Void)? = nil
    var panelColor: Color = Palette.purpleLight   //  (por defecto morado para user)

    var body: some View {
        HStack(spacing: 0) {
            // Panel de color (configurable)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 18))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.custom("Montserrat-Regular", size: 15))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelColor)              // depende del elegido azul o morado por restaurant o user

            ZStack(alignment: .topTrailing) {
                RemoteImage(urlString: imageURL)
                    .frame(width: 160, height: 124)
                    .clipped()
                    .background(Color.white)

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

// Cargador simple de imagen 
struct RemoteImage: View {
    let urlString: String
    var body: some View {
        if let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                case .failure(_): Color.gray.opacity(0.2)
                case .empty: ProgressView()
                @unknown default: Color.gray.opacity(0.2)
                }
            }
        } else if urlString.starts(with: "data:image") {
            if let comma = urlString.firstIndex(of: ","),
               let data = Data(base64Encoded: String(urlString[urlString.index(after: comma)...])),
               let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        } else {
            Image(urlString).resizable().scaledToFill() // fallback a assets
        }
    }
}
