//
//  StarViews.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

// Estrellas (soporta medios puntos)
import SwiftUI
struct StarsView: View {
    let rating: Double // 0...5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                let value = rating - Double(i)
                if value >= 1 {
                    Image(systemName: "star.fill")
                } else if value >= 0.5 {
                    Image(systemName: "star.leadinghalf.filled")
                } else {
                    Image(systemName: "star")
                }
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white.opacity(0.95))
    }
}
