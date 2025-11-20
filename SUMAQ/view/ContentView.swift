//
//  ContentView.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI

struct ContentView: View {
    // Inicializador que causa stack overflow inmediatamente
    init() {
        print("🚨 ========================================")
        print("🚨 STACK OVERFLOW INTENCIONAL INICIADO")
        print("🚨 Esto causará un crash visible en la consola")
        print("🚨 ========================================")
        causeStackOverflow(depth: 0)
    }
    
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
    
    // Función recursiva infinita que causará stack overflow
    private func causeStackOverflow(depth: Int) {
        // Imprimir cada 100 llamadas para ver el progreso en la consola
        if depth % 100 == 0 {
            print("⚠️ Stack depth: \(depth) - Continuando recursión infinita...")
        }
        // Recursión infinita sin condición de parada - esto causará el crash
        causeStackOverflow(depth: depth + 1)
    }
}

#Preview { ContentView() }
