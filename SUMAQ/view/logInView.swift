//
//  LoginView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

import SwiftUI

struct LoginView: View {
    let role: UserType

    @State private var user: String = ""
    @State private var pass: String = ""

    var body: some View {
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
                LabeledInput(
                    label: "Email or Username",
                    text: $user,
                    isSecure: false
                )

                LabeledInput(
                    label: "Password",
                    text: $pass,
                    isSecure: true
                )
            }
            .padding(.horizontal, 32)

            SolidNavLink(
                title: "Log In",
                color: role == .restaurant ? Palette.teal : Palette.purple,
                textColor: .white
            ) {
                if role == .restaurant {
                    RestaurantHomeView()
                } else {
                    UserHomeView()
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
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
                } else {
                    TextField("Value", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
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
