//
//  ChoiceUserView.swift
//  SUMAQ
//
//  Created by Gabriela Escobar Rojas on 18/09/25.
//

import SwiftUI

struct ChoiceUserView: View {
    private let purple = Color(hex: 0x792765) // morado
    private let teal   = Color(hex: 0x276F79) // azulito

    var body: some View {
        VStack {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
               

            Spacer()
            // Botones abajo
            VStack(spacing: 16) {
                NavigationLink {
                    LogInAndRegisterView(role: .user)
                } label: {
                    Text("User")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundColor(.white)
                        .background(purple)
                        .clipShape(Capsule())
                        .shadow(radius: 2, y: 1)
                }

                NavigationLink {
                    LogInAndRegisterView(role: .restaurant)
                } label: {
                    Text("Restaurant")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundColor(.white)
                        .background(teal)
                        .clipShape(Capsule())
                        .shadow(radius: 2, y: 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)

    }
}




#Preview { ChoiceUserView() }



enum UserType {
    case user
    case restaurant
}
