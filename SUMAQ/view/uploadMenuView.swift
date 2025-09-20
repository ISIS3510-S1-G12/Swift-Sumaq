import SwiftUI

struct UploadMenuView: View {
    var restaurantName: String = "Lucille"   
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

                Text("Upload your Offers")
                    .font(.custom("Mukta-Bold", size: 28))
                    .foregroundColor(Palette.burgundy)
                    .padding(.top, 6)

                Image(systemName: "tray.and.arrow.up")
                    .font(.system(size: 140, weight: .regular))
                    .foregroundColor(Palette.burgundy)
                    .padding(.top, 4)

                Button(action: {}) {
                    Text("Upload Offers")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundColor(.white)
                }
                .buttonStyle(UploadPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
        }
    }
}

// Estilo del botón (naranja suave, bordes redondeados)
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

#Preview("UploadMenuView") {
    UploadMenuView(restaurantName: "Lucille")
        .environment(\.colorScheme, .light)
        .previewDevice("iPhone 15 Pro")
}
