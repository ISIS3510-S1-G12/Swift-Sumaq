//
//  CrowdController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import CoreBluetooth

final class CrowdController: NSObject, ObservableObject {
    // Estado público (observer)
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var nearbyCount = 0
    @Published var lastError: String?

    // CoreBluetooth
    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!

    // Periféricos únicos vistos durante el escaneo actual
    private var seen: Set<UUID> = []
    private var scanTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: - API
    func startQuickScan(duration: TimeInterval = 10) {
        lastError = nil
        seen.removeAll()
        nearbyCount = 0
        NotificationCenter.default.post(name: .crowdScanDidStart, object: nil)

        // Empezamos a anunciar para que otros también nos cuenten
        startAdvertising()

        if central.state == .poweredOn {
            startScan()
        } else {
            // Se iniciará en centralManagerDidUpdateState cuando encienda
        }

        // Autostop
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }

    func stop() {
        stopScan()
        stopAdvertising()
        lastError = nil
    }

    // MARK: - Internos
    private func startScan() {
        guard !isScanning else { return }
        isScanning = true
        let opts: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        central.scanForPeripherals(withServices: [CrowdBLE.serviceUUID], options: opts)
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
            // se arrancará en peripheralManagerDidUpdateState
            return
        }
        let data: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [CrowdBLE.serviceUUID],
            CBAdvertisementDataLocalNameKey: "SUMAQ"
        ]
        peripheral.startAdvertising(data)
        isAdvertising = true
    }

    private func stopAdvertising() {
        guard isAdvertising else { return }
        peripheral.stopAdvertising()
        isAdvertising = false
    }
}

// MARK: - CBCentralManagerDelegate
extension CrowdController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isScanning { startScan() }
        case .unauthorized:
            lastError = "Bluetooth permission denied."
        case .unsupported:
            lastError = "Bluetooth unsupported on this device."
        case .poweredOff:
            lastError = "Bluetooth is off."
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        // contamos “cerca”
        guard RSSI.intValue > CrowdBLE.rssiCloseThreshold else { return }

        if seen.insert(peripheral.identifier).inserted {
            nearbyCount = seen.count
            NotificationCenter.default.post(name: .crowdScanDidUpdate, object: nil,
                                            userInfo: ["count": nearbyCount])
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if isAdvertising == false { startAdvertising() }
        case .unauthorized:
            lastError = "Bluetooth permission denied."
        case .unsupported:
            lastError = "Peripheral unsupported on this device."
        case .poweredOff:
            // si apagan BT, paramos todo
            stop()
        default:
            break
        }
    }
}
