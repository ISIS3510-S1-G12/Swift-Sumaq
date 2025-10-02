import SwiftUI

struct ReviewCard: View {
    let author: String
    let restaurant: String
    let rating: Int
    let comment: String
    var avatarURL: String = ""
    var reviewImageURL: String? = nil     // NUEVO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                avatarView
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(author)
                            .font(.custom("Montserrat-SemiBold", size: 15))
                            .foregroundColor(Palette.burgundy)
                        Spacer(minLength: 8)
                        StarsRow(rating: rating)
                    }

                    Text(restaurant)
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .foregroundColor(.primary)

                    Text(comment)
                        .font(.custom("Montserrat-Regular", size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let url = reviewImageURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RemoteImage(urlString: url)
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        let trimmed = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Palette.burgundy.opacity(0.85))
        } else if trimmed.hasPrefix("http") || trimmed.hasPrefix("data:image") {
            RemoteImage(urlString: trimmed).scaledToFill()
        } else {
            Image(trimmed).resizable().scaledToFill()
        }
    }
}
