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

        startAdvertising()

        if central.state == .poweredOn {
            startScan()
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
        isScanning = true
        central.scanForPeripherals(withServices: [CrowdBLE.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
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
        guard peripheral.state == .poweredOn else { return }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CrowdBLE.serviceUUID],
            CBAdvertisementDataLocalNameKey: "SUMAQ"
        ])
        isAdvertising = true
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

        guard RSSI.intValue > CrowdBLE.rssiCloseThreshold else { return }
        if seen.insert(peripheral.identifier).inserted {
            nearbyCount = seen.count
            NotificationCenter.default.post(name: .crowdScanDidUpdate,
                                            object: nil, userInfo: ["count": nearbyCount])
        }
    }
}

extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if isAdvertising == false { startAdvertising() }
        case .unauthorized: lastError = "Bluetooth permission denied."
        case .unsupported:  lastError = "Peripheral unsupported on this device."
        case .poweredOff:   stop()
        default: break
        }
    }
}
