//
//  Colors.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Palette {
    static let purple     = Color(hex: 0x792765) // morado
    static let purpleLight = Color(hex: 0xAA6299) // morado claro
    static let orange     = Color(hex: 0xCE7B49) // search bar
    static let teal       = Color(hex: 0x276F79) // azulito principal
    static let tealLight  = Color(hex: 0x6BB8C2) // #6BB8C2
    static let grayLight  = Color(hex: 0xE5E5E6) // #E5E5E6
    static let orangeAlt  = Color(hex: 0xC37F53) // #C37F53
    static let burgundy   = Color(hex: 0x72322B) // #72322B
}
