import SwiftUI

struct RegisterView: View {
    let role: UserType

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    private var accentColor: Color {
        role == .user ? Palette.purple : Palette.teal
    }
    private var buttonColor: Color {
        role == .user ? Palette.purple : Palette.teal
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel("App logo")

                Text("Join SUMAQ")
                      .font(.system(size: 40, weight: .bold, design: .default))
                      .foregroundStyle(accentColor)
                      .kerning(1)


                VStack(alignment: .leading, spacing: 18) {
                    LabeledField(
                        title: "Name",
                        text: $name,
                        placeholder: "Value",
                        keyboard: .default,
                        autocap: .words,
                        labelColor: Palette.burgundy
                    )

                    LabeledField(
                        title: "Email",
                        text: $email,
                        placeholder: "Value",
                        keyboard: .emailAddress,
                        autocap: .never,
                        labelColor: Palette.burgundy
                    )
                    .textInputAutocapitalization(.never)

                    LabeledField(
                        title: "Username",
                        text: $username,
                        placeholder: "Value",
                        keyboard: .default,
                        autocap: .never,
                        labelColor: Palette.burgundy
                    )
                    .textInputAutocapitalization(.never)

                    LabeledSecureField(
                        title: "Password",
                        text: $password,
                        placeholder: "Value",
                        labelColor: Palette.burgundy
                    )
                    .textInputAutocapitalization(.never)
                }

                // Botón Register
                Button(action: {}) {
                    Text("Register")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: buttonColor))
                .padding(.top, 6)

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct LabeledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .never
    var labelColor: Color = Palette.burgundy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            TextField(placeholder, text: $text)
                .font(.custom("Montserrat-Regular", size: 16))
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Palette.grayLight) // usa Palette
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var labelColor: Color = Palette.burgundy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(labelColor)

            SecureField(placeholder, text: $text)
                .font(.custom("Montserrat-Regular", size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Palette.grayLight) // usa Palette
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct PrimaryCapsuleButton: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color)
            )
            .shadow(radius: configuration.isPressed ? 0 : 2,
                    x: 0, y: configuration.isPressed ? 0 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}


#Preview("Register – Usuario") {
    RegisterView(role: .user)
        .environment(\.colorScheme, .light)
        .previewDevice("iPhone 15 Pro")
}

#Preview("Register – Restaurante") {
    RegisterView(role: .restaurant)
        .environment(\.colorScheme, .light)
        .previewDevice("iPhone 15 Pro")
}
