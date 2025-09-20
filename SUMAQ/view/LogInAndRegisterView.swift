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
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 40)

                Text("WELCOME")
                    .font(.system(size: 40, weight: .bold, design: .default))
                    .foregroundStyle(titleColor)
                    .tracking(1)

                VStack(spacing: 18) {

                    SolidNavLink(
                        title: "Log In",
                        color: buttonColor,
                        textColor: .white
                    ) {
                        LoginView(role: role)
                    }

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




