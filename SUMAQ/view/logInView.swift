//
//  LoginView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

import SwiftUI

struct LoginView: View {
    let role: UserType

    // Inputs
    @State private var user: String = ""   // email
    @State private var pass: String = ""

    // UI state
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var goToUserHome = false
    @State private var goToRestaurantHome = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .cornerRadius(24)
                    .shadow(radius: 4, y: 2)
                    .padding(.top, 24)

                Text("WELCOME")
                    .font(.system(size: 40, weight: .bold, design: .default))
                    .foregroundColor(role == .restaurant ? Palette.teal : Palette.purple)
                    .tracking(1)

                VStack(alignment: .leading, spacing: 18) {
                    LabeledInput(label: "Email", text: $user, isSecure: false)
                    LabeledInput(label: "Password", text: $pass, isSecure: true)
                }
                .padding(.horizontal, 32)

                Button {
                    doLogin()
                } label: {
                    Text(isLoading ? "Signing in..." : "Log In")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PrimaryCapsuleButton(color: role == .restaurant ? Palette.teal : Palette.purple))
                .padding(.horizontal, 32)
                .disabled(isLoading || user.isEmpty || pass.isEmpty)

                if let errorMsg {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }
                
                NavigationLink(destination: UserRootView(),
                               isActive: $goToUserHome) { EmptyView() }
                    .hidden()


                NavigationLink(destination: RestaurantHomeView(),
                               isActive: $goToRestaurantHome) { EmptyView() }
                    .hidden()

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
        }
    }

    private func doLogin() {
        errorMsg = nil
        isLoading = true

        login(email: user, password: pass) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let dest):
                    switch dest {
                    case .userHome:
                        goToUserHome = true
                    case .restaurantHome:
                        goToRestaurantHome = true
                    }
                case .failure(let e):
                    errorMsg = e.localizedDescription
                }
            }
        }
    }
}

private struct LabeledInput: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundColor(Palette.burgundy)

            Group {
                if isSecure {
                    SecureField("Value", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } else {
                    TextField("Value", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(label.lowercased().contains("email") ? .emailAddress : .default)
                }
            }
            .font(.custom("Montserrat-Regular", size: 16))
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Palette.grayLight) // #E5E5E6
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
