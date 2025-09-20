//
//  LoginView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI

import SwiftUI

struct LoginView: View {
    let role: UserType

    var body: some View {
        VStack(spacing: 28) {

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 40)
            
            Text("WELCOME")
                .font(.system(size: 40, weight: .bold, design: .default))
                .foregroundColor(role == .user ? Palette.purple : Palette.teal)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email or Username")
                        .font(.custom("Montserrat-Regular", size: 14))
                        .foregroundColor(.gray)
                    TextField("Value", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.custom("Montserrat-Regular", size: 14))
                        .foregroundColor(.gray)
                    SecureField("Value", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 32)
            
            SolidNavLink(
                title: "Log In",
                color: role == .user ? Palette.purple : Palette.teal,
                textColor: .white
            ) {
                if role == .restaurant {
                    RestaurantHomeView()
                } else {
                    UserHomeView()
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
