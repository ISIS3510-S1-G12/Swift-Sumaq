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
    private var pendingScan = false // Para manejar scans pendientes

    override init() {
        super.init()
        
        // Inicializar con un queue dedicado para evitar problemas de concurrencia
        let queue = DispatchQueue(label: "com.sumaq.bluetooth", qos: .userInitiated)
        central = CBCentralManager(delegate: self, queue: queue)
        peripheral = CBPeripheralManager(delegate: self, queue: queue)
        
        print("🔵 CrowdController initialized")
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

        print("🔵 Starting scan - Central state: \(central.state.rawValue), Peripheral state: \(peripheral.state.rawValue)")
        
        // Verificar si estamos en simulador
        #if targetEnvironment(simulator)
        print("🔵 Running on simulator - Bluetooth functionality is limited")
        lastError = "Bluetooth detection is limited on simulator. Please test on a real device for full functionality."
        pendingScan = false
        return
        #endif

        // Verificar que Bluetooth esté disponible
        guard central.state != .unsupported else {
            lastError = "Bluetooth is not supported on this device"
            pendingScan = false
            return
        }
        
        // Manejar estado .unknown - puede ser que necesite más tiempo para inicializar
        if central.state == .unknown || peripheral.state == .unknown {
            print("🔵 Bluetooth state is unknown, waiting for initialization...")
            lastError = "Bluetooth is initializing... Please wait a moment and try again."
            
            // Dar tiempo para que Bluetooth se inicialice
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.pendingScan {
                    print("🔵 Retrying after delay - Central state: \(self.central.state.rawValue), Peripheral state: \(self.peripheral.state.rawValue)")
                    if self.central.state == .poweredOn && self.peripheral.state == .poweredOn {
                        self.startAdvertising()
                        self.startScan()
                        self.pendingScan = false
                        self.lastError = nil
                    } else if self.central.state == .unknown || self.peripheral.state == .unknown {
                        self.lastError = "Bluetooth initialization failed. Please check permissions and try again."
                        self.pendingScan = false
                    }
                }
            }
            return
        }
        
        guard central.state != .poweredOff else {
            lastError = "Please turn on Bluetooth to scan for nearby devices"
            pendingScan = false
            return
        }

        // Iniciar advertising si el peripheral está listo
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            print("🔵 Peripheral not ready, state: \(peripheral.state.rawValue)")
        }

        // Iniciar scan si el central está listo
        if central.state == .poweredOn {
            startScan()
            pendingScan = false
        } else {
            print("🔵 Central not ready, state: \(central.state.rawValue)")
            lastError = "Initializing Bluetooth... (\(central.state.rawValue))"
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
            print("🔵 Already scanning, skipping")
            return 
        }
        guard central.state == .poweredOn else { 
            print("🔵 Central not powered on, cannot scan. State: \(central.state.rawValue)")
            return 
        }
        
        print("🔵 Starting scan for all Bluetooth devices")
        isScanning = true
        // Escanear todos los dispositivos Bluetooth, no solo los con servicio específico
        central.scanForPeripherals(withServices: nil,
                                   options: [
                                    CBCentralManagerScanOptionAllowDuplicatesKey: false
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
        guard !isAdvertising else { 
            print("🔵 Already advertising, skipping")
            return 
        }
        guard peripheral.state == .poweredOn else { 
            print("🔵 Peripheral not powered on, cannot advertise. State: \(peripheral.state.rawValue)")
            lastError = "Peripheral manager not ready. State: \(peripheral.state.rawValue)"
            return 
        }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "SUMAQ"
        ]
        
        print("🔵 Starting advertising as generic Bluetooth device")
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
        print("🔵 Central state changed to: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            lastError = nil
            if pendingScan {
                startScan()
                pendingScan = false
            }
        case .unauthorized: 
            lastError = "Bluetooth permission denied. Please enable in Settings."
            pendingScan = false
        case .unsupported:  
            lastError = "Bluetooth unsupported on this device."
            pendingScan = false
        case .poweredOff:   
            lastError = "Bluetooth is turned off. Please turn it on."
            pendingScan = false
        case .resetting:
            lastError = "Bluetooth is resetting. Please wait..."
        case .unknown:
            print("🔵 Central state is unknown, this is normal during initialization")
            // No establecer error aquí, es normal durante la inicialización
        @unknown default:
            lastError = "Unknown Bluetooth state. Please try again."
            pendingScan = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        let rssiValue = RSSI.intValue
        print("🔵 Discovered peripheral: \(peripheral.identifier), RSSI: \(rssiValue)")
        
        // Verificar que el RSSI esté dentro del rango aceptable
        guard rssiValue > CrowdBLE.rssiCloseThreshold else { 
            print("🔵 RSSI too weak: \(rssiValue) <= \(CrowdBLE.rssiCloseThreshold)")
            return 
        }
        
        // Detectar cualquier dispositivo Bluetooth cercano
        if seen.insert(peripheral.identifier).inserted {
            nearbyCount = seen.count
            print("🔵 New Bluetooth device found! RSSI: \(rssiValue), Total nearby: \(nearbyCount)")
            NotificationCenter.default.post(name: .crowdScanDidUpdate,
                                            object: nil, userInfo: ["count": nearbyCount])
        } else {
            print("🔵 Already seen this device")
        }
    }
}

extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("🔵 Peripheral state changed to: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            if !isAdvertising && pendingScan { 
                startAdvertising()
            }
            // No limpiar lastError aquí, puede estar esperando por central
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
        case .unknown:
            print("🔵 Peripheral state is unknown, this is normal during initialization")
            // No establecer error aquí, es normal durante la inicialización
        @unknown default: 
            lastError = "Unknown Bluetooth state. Please try again."
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("🔵 Failed to start advertising: \(error.localizedDescription)")
            lastError = "Failed to start advertising: \(error.localizedDescription)"
            isAdvertising = false
        } else {
            print("🔵 Successfully started advertising")
            isAdvertising = true
            // Solo limpiar error si tanto central como peripheral están funcionando
            if central.state == .poweredOn && peripheral.state == .poweredOn {
                lastError = nil
            }
        }
    }
}
