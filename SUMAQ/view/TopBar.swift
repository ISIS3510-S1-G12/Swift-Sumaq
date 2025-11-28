import SwiftUI

struct TopBar: View {
    private let lineColor: Color = Palette.burgundy
    private let lineHeight: CGFloat = 1
    private let sidePadding: CGFloat = 16
    
    // 👇 Closure opcional con valor por defecto
    var onAvatarTap: () -> Void = {}

    @ObservedObject private var session = SessionController.shared

    private var displayName: String {
        if let n = session.currentUser?.name, !n.isEmpty { return n }
        return "Mi sesión"
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if let profileURL = session.currentUser?.profilePictureURL, !profileURL.isEmpty {
            RemoteImage(urlString: profileURL)
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.burgundy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // 👇 Solo el avatar es botón
                    Button(action: onAvatarTap) {
                        profileImageView
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, sidePadding)

            Rectangle()
                .fill(lineColor)
                .frame(height: lineHeight)
                .padding(.horizontal, sidePadding)
        }
    }
}
