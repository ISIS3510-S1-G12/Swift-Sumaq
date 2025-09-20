import SwiftUI

struct LogInAndRegisterView: View {
    let role: UserType

    private var titleColor: Color {
        role == .user ? Palette.purple : Palette.teal
    }

    private var buttonColor: Color {
        role == .user ? Palette.purple : Palette.teal
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 40)

                Text("WELCOME")
                    .font(.custom("Mukta-Bold", size: 36))
                    .foregroundStyle(titleColor)
                    .tracking(1)

                VStack(spacing: 18) {

                //    SolidNavLink(
                 //       title: "Log In",
                 //       color: buttonColor,
                  //      textColor: .white
                 //   ) {
                 //       LoginView(role: role)
                 //   }

                    SolidNavLink(
                        title: "Register",
                        color: buttonColor,
                        textColor: .white
                    ) {
                        RegisterView(role: role)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
        }
    }
}

struct SolidButton: View {
    let title: String
    let color: Color
    let textColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Mukta-Bold", size: 18))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(radius: 2, y: 1)
    }
}



#Preview("Usuario (Morado)") {
    LogInAndRegisterView(role: .user)
}

#Preview("Restaurante (Teal)") {
    LogInAndRegisterView(role: .restaurant)
}
