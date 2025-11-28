//
//  ContentView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var session = SessionController.shared

    var body: some View {
        Group {
            if !session.isAuthenticated {
                // NO hay sesión → mostrar pantalla inicial (login/registro)
                NavigationStack {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        
                        NavigationLink {
                            ChoiceUserView()
                        } label: {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            } else {
                // SÍ hay sesión → mostrar root de usuario / restaurante
                NavigationStack {
                    if session.role == .user {
                        UserRootView()
                    } else if session.role == .restaurant {
                        RestaurantHomeView()   // si tienes uno
                    } else {
                        ProgressView("Loading profile…")
                    }
                }
            }
        }
        .task { _ = SessionController.shared }  // asegurar inicialización del listener
    }
}
