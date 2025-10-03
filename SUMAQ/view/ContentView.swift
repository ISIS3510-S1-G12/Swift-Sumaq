//
//  ContentView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
        .task { _ = SessionController.shared }
    }
}

#Preview { ContentView() }
