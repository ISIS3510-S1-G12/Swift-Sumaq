//
//  Colors+Hex.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI

// ÚNICA extensión para todo el proyecto
extension Color {
    /// Hex como entero: 0xRRGGBB (opcional alpha)
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Hex como string “#RRGGBB” o “RRGGBB”
    init(hex string: String, alpha: Double = 1.0) {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let scanner = Scanner(string: s)
        var hex: UInt64 = 0
        scanner.scanHexInt64(&hex)
        self.init(hex: UInt32(hex), alpha: alpha)
    }
}

// Paleta centralizada
enum Palette {
    static let purple = Color(hex: 0x792765)
    static let teal   = Color(hex: 0x276F79)
    static let orange = Color(hex: 0xCE7B49)
}
