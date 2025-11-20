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
        // Forzar stack overflow con recursión profunda y estructuras grandes
        print("🚨 ========================================")
        print("🚨 STACK OVERFLOW INTENCIONAL INICIADO")
        print("🚨 Esto causará un error visible en ROJO en Xcode")
        print("🚨 ========================================")
        
        // Forzar el stack overflow real con recursión profunda
        // Esto causará un crash que aparecerá en rojo en la consola de Xcode
        causeStackOverflow(depth: 0, largeArray: Array(repeating: 0, count: 1000))
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
    // Usa arrays grandes y callStackSymbols para consumir más stack space
    private func causeStackOverflow(depth: Int, largeArray: [Int]) {
        // Imprimir cada 10 llamadas para ver el progreso
        if depth % 10 == 0 {
            let stackTrace = Thread.callStackSymbols
            print("⚠️ Stack depth: \(depth) - Stack symbols: \(stackTrace.count)")
        }
        
        // Crear múltiples arrays grandes en cada llamada para consumir más stack
        let array1 = Array(repeating: depth, count: 2000)
        let array2 = Array(repeating: depth * 2, count: 2000)
        let array3 = Array(repeating: depth * 3, count: 2000)
        
        // Obtener el stack trace para consumir aún más stack
        let stackTrace = Thread.callStackSymbols
        
        // Cuando el stack esté muy profundo, lanzar un error que aparecerá en ROJO
        if depth >= 200 {
            // Esto aparecerá en ROJO en la consola de Xcode
            assertionFailure("🚨 STACK OVERFLOW DETECTADO - Profundidad: \(depth). Stack trace tiene \(stackTrace.count) símbolos. Este es un error intencional para testing.")
        }
        
        // Recursión infinita sin condición de parada - esto causará el crash real
        // El stack overflow real aparecerá en rojo en Xcode cuando ocurra
        causeStackOverflow(depth: depth + 1, largeArray: array1 + array2 + array3)
    }
}

#Preview { ContentView() }
