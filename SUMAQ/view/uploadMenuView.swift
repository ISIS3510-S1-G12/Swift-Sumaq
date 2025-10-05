// este archivo tampoco es usado actualmente
import SwiftUI

struct UploadMenuView: View {
    var restaurantName: String = "Lucille"
    @State private var showingSuccess = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {

                HStack {
                    Image("AppLogoUI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Spacer()

                    Image("LucilleLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Rectangle()
                    .fill(Palette.burgundy)
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Palette.burgundy)

                    Text(restaurantName)
                        .font(.custom("Montserrat-SemiBold", size: 24))
                        .foregroundColor(Palette.teal)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Text("Upload your new menu")
                    .font(.custom("Mukta-Bold", size: 28))
                    .foregroundColor(Palette.burgundy)
                    .padding(.top, 6)

                Image(systemName: "tray.and.arrow.up")
                    .font(.system(size: 140, weight: .regular))
                    .foregroundColor(Palette.burgundy)
                    .padding(.top, 4)

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showingSuccess = true
                    }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }) {
                    Text("Upload Menu")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundColor(.white)
                }
                .buttonStyle(UploadPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .blur(radius: showingSuccess ? 2 : 0)

            if showingSuccess {
                SuccessOverlay {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showingSuccess = false
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showingSuccess)
    }
}

struct UploadPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.tealLight.opacity(0.95))
            )
            .shadow(radius: configuration.isPressed ? 0 : 2, x: 0, y: configuration.isPressed ? 0 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SuccessOverlay: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Fondo oscurecido
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(Color(hex: "#1C6B71"))

                Text("Upload successful")
                    .font(.custom("Montserrat-SemiBold", size: 24))
                    .foregroundColor(Color(hex: "#1C6B71"))

                Text("Your menu has been successfully uploaded!!")
                    .multilineTextAlignment(.center)
                    .font(.custom("Montserrat-Regular", size: 16))
                    .foregroundColor(.black.opacity(0.75))

                Spacer().frame(height: 12)

                Button(action: onDismiss) {
                    Text("OK")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .foregroundColor(Color(hex: "#1C6B71"))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "#C4E3E5"))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
            )
        }
        .accessibilityAddTraits(.isModal)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#Preview("UploadMenuView") {
    UploadMenuView(restaurantName: "Lucille")
        .environment(\.colorScheme, .light)
        .previewDevice("iPhone 15 Pro")
}
