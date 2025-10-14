//
//  BluetoothConstants.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//


import CoreBluetooth

enum CrowdBLE {
    // UUID personalizado más simple para SUMAQ
    static let serviceUUID = CBUUID(string: "1234")
    static let rssiCloseThreshold = -80  // Hacer el threshold menos estricto
}
