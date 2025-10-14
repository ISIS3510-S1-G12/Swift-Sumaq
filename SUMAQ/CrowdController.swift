//
//  CrowdController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//


import Foundation
import CoreBluetooth

final class CrowdController: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var nearbyCount = 0
    @Published var lastError: String?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!

    private var seen: Set<UUID> = []
    private var scanTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }

    deinit {
        stop()
        scanTimer?.invalidate()
        scanTimer = nil
    }

    func startQuickScan(duration: TimeInterval = 10) {
        lastError = nil
        seen.removeAll()
        nearbyCount = 0
        NotificationCenter.default.post(name: .crowdScanDidStart, object: nil)

        // Verificar que Bluetooth esté disponible
        guard central.state != .unsupported else {
            lastError = "Bluetooth is not supported on this device"
            return
        }
        
        guard central.state != .poweredOff else {
            lastError = "Please turn on Bluetooth to scan for nearby devices"
            return
        }

        startAdvertising()

        if central.state == .poweredOn {
            startScan()
        } else {
            // Si no está poweredOn, esperamos a que se active en centralManagerDidUpdateState
            lastError = "Initializing Bluetooth..."
        }

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }

    func stop() {
        stopScan()
        stopAdvertising()
        lastError = nil
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func startScan() {
        guard !isScanning else { return }
        guard central.state == .poweredOn else { return }
        
        isScanning = true
        central.scanForPeripherals(withServices: [CrowdBLE.serviceUUID],
                                   options: [
                                    CBCentralManagerScanOptionAllowDuplicatesKey: false,
                                    CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [CrowdBLE.serviceUUID]
                                   ])
    }

    private func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        NotificationCenter.default.post(name: .crowdScanDidFinish, object: nil,
                                        userInfo: ["count": nearbyCount])
    }

    private func startAdvertising() {
        guard !isAdvertising else { return }
        guard peripheral.state == .poweredOn else { 
            lastError = "Peripheral manager not ready. State: \(peripheral.state.rawValue)"
            return 
        }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [CrowdBLE.serviceUUID],
            CBAdvertisementDataLocalNameKey: "SUMAQ"
        ]
        
        peripheral.startAdvertising(advertisementData)
        // isAdvertising se establecerá en true cuando se confirme en peripheralManagerDidStartAdvertising
    }

    private func stopAdvertising() {
        guard isAdvertising else { return }
        peripheral.stopAdvertising()
        isAdvertising = false
    }
}

extension CrowdController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isScanning { startScan() }
        case .unauthorized: lastError = "Bluetooth permission denied."
        case .unsupported:  lastError = "Bluetooth unsupported on this device."
        case .poweredOff:   lastError = "Bluetooth is off."
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        // Verificar que el RSSI esté dentro del rango aceptable
        let rssiValue = RSSI.intValue
        guard rssiValue > CrowdBLE.rssiCloseThreshold else { return }
        
        // Verificar que el dispositivo tenga nuestro servicio
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           services.contains(CrowdBLE.serviceUUID) {
            
            if seen.insert(peripheral.identifier).inserted {
                nearbyCount = seen.count
                NotificationCenter.default.post(name: .crowdScanDidUpdate,
                                                object: nil, userInfo: ["count": nearbyCount])
            }
        }
    }
}

extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if !isAdvertising { 
                startAdvertising()
                lastError = nil // Limpiar error si estaba presente
            }
        case .unauthorized: 
            lastError = "Bluetooth permission denied. Please enable in Settings."
            stop()
        case .unsupported:  
            lastError = "Bluetooth advertising is not supported on this device."
            stop()
        case .poweredOff:   
            lastError = "Bluetooth is turned off. Please turn it on to use this feature."
            stop()
        case .resetting:
            lastError = "Bluetooth is resetting. Please wait..."
        default: 
            lastError = "Bluetooth state unknown. Please try again."
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            lastError = "Failed to start advertising: \(error.localizedDescription)"
            isAdvertising = false
        } else {
            isAdvertising = true
            lastError = nil // Limpiar cualquier error previo
        }
    }
}
