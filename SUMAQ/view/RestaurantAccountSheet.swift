//
//  RestaurantAccountSheet.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import SwiftUI
import FirebaseAuth

/// Hoja simple con acciones de cuenta para restaurante.
struct RestaurantAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var onLoggedOut: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Palette.teal)

                Text("Account")
                    .font(.custom("Montserrat-Bold", size: 22))
                    .foregroundStyle(Palette.burgundy)

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    do {
                        try Auth.auth().signOut()
                        onLoggedOut?()
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                } label: {
                    Text("Log out")
                        .font(.custom("Montserrat-SemiBold", size: 18))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(PrimaryCapsuleButton(color: Palette.teal))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
        }
    }
}
