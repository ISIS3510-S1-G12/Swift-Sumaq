//
//  BluetoothConstants.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//


import CoreBluetooth

enum CrowdBLE {
    // UUID propietario para anunciar/escuchar a otros SUMAQ cerca
    static let serviceUUID = CBUUID(string: "A8F0C9A2-4D43-4F58-9A71-2AA1B987C0A1")
    // Umbral aproximado de cercanía (mientras más alto, más cerca)
    static let rssiCloseThreshold = -75  // dBm
}
