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

    // Closure properties for event callbacks
    var onCentralStateChange: ((CBManagerState) -> Void)?
    var onPeripheralStateChange: ((CBManagerState) -> Void)?
    var onScanStarted: (() -> Void)?
    var onScanStopped: ((Int) -> Void)?
    var onDeviceFound: ((UUID, Int, Int) -> Void)?
    var onAdvertisingStarted: (() -> Void)?
    var onAdvertisingStopped: ((Error?) -> Void)?
    var onError: ((String) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!

    private var seen: Set<UUID> = []
    private var scanTimer: Timer?
    private var pendingScan = false

    override init() {
        super.init()
        
        let queue = DispatchQueue(label: "com.sumaq.bluetooth", qos: .userInitiated)
        central = CBCentralManager(delegate: self, queue: queue)
        peripheral = CBPeripheralManager(delegate: self, queue: queue)
        
        print("CrowdController initialized")
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
        pendingScan = true
        NotificationCenter.default.post(name: .crowdScanDidStart, object: nil)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onScanStarted?()
        }
        
        #if targetEnvironment(simulator)
        print("Running on simulator - Bluetooth functionality is limited")
        lastError = "Bluetooth detection is limited on simulator. Please test on a real device for full functionality."
        pendingScan = false
        let errorMsg = "Bluetooth detection is limited on simulator. Please test on a real device for full functionality."
        DispatchQueue.main.async { [weak self] in
            self?.onError?(errorMsg)
        }
        return
        #endif

        guard central.state != .unsupported else {
            lastError = "Bluetooth is not supported on this device"
            pendingScan = false
            let errorMsg = "Bluetooth is not supported on this device"
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            return
        }
        
        if central.state == .unknown || peripheral.state == .unknown {
            print("Bluetooth state is unknown, waiting for initialization...")
            lastError = "Bluetooth is initializing... Please wait a moment and try again."
            let errorMsg = "Bluetooth is initializing... Please wait a moment and try again."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.pendingScan {
                    print("Retrying after delay - Central state: \(self.central.state.rawValue), Peripheral state: \(self.peripheral.state.rawValue)")
                    if self.central.state == .poweredOn && self.peripheral.state == .poweredOn {
                        self.startAdvertising()
                        self.startScan()
                        self.pendingScan = false
                        self.lastError = nil
                    } else if self.central.state == .unknown || self.peripheral.state == .unknown {
                        let errorMsg = "Bluetooth initialization failed. Please check permissions and try again."
                        self.lastError = errorMsg
                        self.onError?(errorMsg)
                        self.pendingScan = false
                    }
                }
            }
            return
        }
        
        guard central.state != .poweredOff else {
            lastError = "Please turn on Bluetooth to scan for nearby devices"
            pendingScan = false
            let errorMsg = "Please turn on Bluetooth to scan for nearby devices"
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            return
        }

        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            print("Peripheral not ready, state: \(peripheral.state.rawValue)")
        }

        if central.state == .poweredOn {
            startScan()
            pendingScan = false
        } else {
            print("Central not ready, state: \(central.state.rawValue)")
            lastError = "Initializing Bluetooth... (\(central.state.rawValue))"
            let errorMsg = "Initializing Bluetooth... (\(central.state.rawValue))"
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
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
        pendingScan = false
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    func debugStatus() -> String {
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        
        return """
        Central State: \(central.state.rawValue) (\(stateDescription(central.state)))
        Peripheral State: \(peripheral.state.rawValue) (\(stateDescription(peripheral.state)))
        Is Scanning: \(isScanning)
        Is Advertising: \(isAdvertising)
        Pending Scan: \(pendingScan)
        Nearby Count: \(nearbyCount)
        Is Simulator: \(isSimulator)
        Last Error: \(lastError ?? "None")
        """
    }
    
    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "unknown"
        }
    }

    private func startScan() {
        guard !isScanning else { 
            print("Already scanning, skipping")
            return 
        }
        guard central.state == .poweredOn else { 
            print("Central not powered on, cannot scan. State: \(central.state.rawValue)")
            return 
        }
        
        print("Starting scan for all Bluetooth devices")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = true
            self.onScanStarted?()
        }
        central.scanForPeripherals(withServices: nil,
                                   options: [
                                    CBCentralManagerScanOptionAllowDuplicatesKey: false
                                   ])
    }

    private func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        let count = nearbyCount
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.onScanStopped?(count)
        }
        NotificationCenter.default.post(name: .crowdScanDidFinish, object: nil,
                                        userInfo: ["count": count])
    }

    private func startAdvertising() {
        guard !isAdvertising else { 
            print("Already advertising, skipping")
            return 
        }
        guard peripheral.state == .poweredOn else { 
            print("Peripheral not powered on, cannot advertise. State: \(peripheral.state.rawValue)")
            let errorMsg = "Peripheral manager not ready. State: \(peripheral.state.rawValue)"
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            return 
        }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "SUMAQ"
        ]
        
        peripheral.startAdvertising(advertisementData)
    }

    private func stopAdvertising() {
        guard isAdvertising else { return }
        peripheral.stopAdvertising()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdvertising = false
            self.onAdvertisingStopped?(nil)
        }
    }
}

extension CrowdController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onCentralStateChange?(state)
        }
        
        switch state {
        case .poweredOn:
            lastError = nil
            if pendingScan {
                startScan()
                pendingScan = false
            }
        case .unauthorized: 
            let errorMsg = "Bluetooth permission denied. Please enable in Settings."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            pendingScan = false
        case .unsupported:  
            let errorMsg = "Bluetooth unsupported on this device."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            pendingScan = false
        case .poweredOff:   
            let errorMsg = "Bluetooth is turned off. Please turn it on."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            pendingScan = false
        case .resetting:
            let errorMsg = "Bluetooth is resetting. Please wait..."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
        case .unknown:
            print("Central state is unknown, this is normal during initialization")
        @unknown default:
            let errorMsg = "Unknown Bluetooth state. Please try again."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            pendingScan = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        let rssiValue = RSSI.intValue
        print("Discovered peripheral: \(peripheral.identifier), RSSI: \(rssiValue)")
        
        guard rssiValue > CrowdBLE.rssiCloseThreshold else {
            print("RSSI too weak: \(rssiValue) <= \(CrowdBLE.rssiCloseThreshold)")
            return 
        }
        
        if seen.insert(peripheral.identifier).inserted {
            let deviceUUID = peripheral.identifier
            let deviceRSSI = rssiValue
            let count = seen.count
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.nearbyCount = count
                self.onDeviceFound?(deviceUUID, deviceRSSI, count)
            }
            
            print("New Bluetooth device found! RSSI: \(rssiValue), Total nearby: \(count)")
            NotificationCenter.default.post(name: .crowdScanDidUpdate,
                                            object: nil, userInfo: ["count": count])
        } else {
            print("Already seen this device")
        }
    }
}

extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        print("Peripheral state changed to: \(state.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onPeripheralStateChange?(state)
        }
        
        switch state {
        case .poweredOn:
            if !isAdvertising && pendingScan { 
                startAdvertising()
            }
        case .unauthorized:
            let errorMsg = "Bluetooth permission denied. Please enable in Settings."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            stop()
        case .unsupported:  
            let errorMsg = "Bluetooth advertising is not supported on this device."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            stop()
        case .poweredOff:   
            let errorMsg = "Bluetooth is turned off. Please turn it on to use this feature."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
            stop()
        case .resetting:
            let errorMsg = "Bluetooth is resetting. Please wait..."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
        case .unknown:
            print("Peripheral state is unknown, this is normal during initialization")
        @unknown default:
            let errorMsg = "Unknown Bluetooth state. Please try again."
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMsg
                self?.onError?(errorMsg)
            }
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed to start advertising: \(error.localizedDescription)")
            let errorMsg = "Failed to start advertising: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lastError = errorMsg
                self.isAdvertising = false
                self.onError?(errorMsg)
                self.onAdvertisingStopped?(error)
            }
        } else {
            print("Successfully started advertising")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isAdvertising = true
                self.onAdvertisingStarted?()
                if self.central.state == .poweredOn && self.peripheral.state == .poweredOn {
                    self.lastError = nil
                }
            }
        }
    }
}