//
//  Untitled.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 24/09/25.
//

import SwiftUI
import FirebaseFirestore

struct TestFirestoreView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Probar Firestore")
                .font(.title)

            Button("Registrar Usuario de Prueba") {
                registrarUsuarioPrueba()
            }
        }
        .padding()
    }

    func registrarUsuarioPrueba() {
        let db = Firestore.firestore()

        // Datos de prueba
        let nuevoUsuario: [String: Any] = [
            "name": "Usuario Prueba",
            "email": "prueba@example.com",
            "role": "user",
            "preferences": [
                "budget": 20000,
                "diet": "vegan"
            ]
        ]

        // Guardar en la colección "Users"
        db.collection("Users").addDocument(data: nuevoUsuario) { error in
            if let error = error {
                print("❌ Error al registrar usuario: \(error.localizedDescription)")
            } else {
                print("✅ Usuario de prueba agregado correctamente")
            }
        }
        
    }
}
