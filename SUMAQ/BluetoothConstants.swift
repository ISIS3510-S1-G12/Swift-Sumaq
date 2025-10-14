//
//  BluetoothConstants.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//


import CoreBluetooth

enum CrowdBLE {
    // Ya no usamos UUID específico - detectamos cualquier dispositivo Bluetooth
    // Mantenemos la constante por compatibilidad
    static let serviceUUID = CBUUID(string: "B0E50E2E-2B7A-4A86-8B4E-3B1E2B6D2A10")
    static let rssiCloseThreshold = -80  // Threshold para detectar dispositivos cercanos
}