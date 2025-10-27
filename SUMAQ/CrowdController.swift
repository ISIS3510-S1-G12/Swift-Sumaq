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

    // Closures opcionales que permiten a los consumidores suscribirse a eventos del controlador.
    // Se invocan siempre en el hilo principal (DispatchQueue.main) para actualizaciones seguras de UI.
    var onCountChange: ((Int) -> Void)?
    var onError: ((String) -> Void)?
    var onScanStateChange: ((Bool) -> Void)?
    var onAdvertisingStateChange: ((Bool) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!

    private var seen: Set<UUID> = []
    private var scanTimer: Timer?
    private var pendingScan = false

    override init() {
        super.init()
        // queue dedicada para callbacks de CoreBluetooth
        let queue = DispatchQueue(label: "com.sumaq.bluetooth", qos: .userInitiated)
        central = CBCentralManager(delegate: self, queue: queue)
        peripheral = CBPeripheralManager(delegate: self, queue: queue)
        print("CrowdController initialized")
    }

    deinit {
        stop()
        scanTimer?.invalidate()
        scanTimer = nil
        // Liberar referencias a closures para evitar memory leaks
        onCountChange = nil
        onError = nil
        onScanStateChange = nil
        onAdvertisingStateChange = nil
    }

    /// escaneo rápido y opcionalmente advertising por un periodo de tiempo.
    func startQuickScan(duration: TimeInterval = 10) {
        lastError = nil
        seen.removeAll()
        nearbyCount = 0
        pendingScan = true

        NotificationCenter.default.post(name: .crowdScanDidStart, object: nil)

        // Notificar inicio de escaneo vía closure (asegurando main thread)
        DispatchQueue.main.async { [weak self] in
            self?.onScanStateChange?(true)
        }

        #if targetEnvironment(simulator)
        // En simulador, CoreBluetooth es limitado.
        lastError = "Bluetooth detection is limited on the simulator. Please test on a real device."
        pendingScan = false
        DispatchQueue.main.async { [weak self] in
            if let error = self?.lastError {
                self?.onError?(error)
            }
            // Simulamos fin de escaneo para no dejar la UI en estado de carga
            self?.onScanStateChange?(false)
        }
        return
        #endif

        guard central.state != .unsupported else {
            lastError = "Bluetooth is not supported on this device."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
            return
        }

        // Si los estados están inicializándose, avisamos y reintentamos
        if central.state == .unknown || peripheral.state == .unknown {
            lastError = "Bluetooth is initializing. Please wait..."
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
            }
            // Reintento  luego de 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                if self.pendingScan {
                    if self.central.state == .poweredOn && self.peripheral.state == .poweredOn {
                        self.startAdvertising()
                        self.startScan()
                        self.pendingScan = false
                        self.lastError = nil
                    } else {
                        self.lastError = "Bluetooth initialization failed. Check permissions and try again."
                        self.pendingScan = false
                        if let error = self.lastError {
                            self.onError?(error)
                        }
                        self.onScanStateChange?(false)
                    }
                }
            }
            return
        }

        guard central.state != .poweredOff else {
            lastError = "Please turn on Bluetooth to scan for nearby devices."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
            return
        }

        // Intentamos advertising si el peripheral ya está listo
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            print("Peripheral not ready, state: \(peripheral.state.rawValue)")
        }

        // Iniciamos escaneo si el central ya está listo
        if central.state == .poweredOn {
            startScan()
            pendingScan = false
        } else {
            print("Central not ready, state: \(central.state.rawValue)")
            lastError = "Initializing Bluetooth... (\(central.state.rawValue))"
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
            }
        }

        // Programamos la detención automática del escaneo
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            print("Timer expired, stopping scan...")
            self?.stopScan()
        }
        
        // Asegurar que el Timer se ejecuta en el RunLoop principal
        if let timer = scanTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Detiene escaneo y advertising, limpia errores y cancela timers.
    func stop() {
        print("Stop() called - stopping scan and advertising")
        stopScan()
        stopAdvertising()
        lastError = nil
        pendingScan = false
        scanTimer?.invalidate()
        scanTimer = nil
        
        // Notificar que el escaneo se detuvo vía closures
        DispatchQueue.main.async { [weak self] in
            self?.onScanStateChange?(false)
            self?.onAdvertisingStateChange?(false)
        }
    }

    /// Estado legible de depuración.
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
            print("Already scanning, skipping.")
            return
        }
        guard central.state == .poweredOn else {
            print("Central not powered on, cannot scan. State: \(central.state.rawValue)")
            return
        }

        print("Starting scan for Bluetooth devices...")
        isScanning = true

        // Escanear con nil para detectar TODOS los dispositivos Bluetooth, no solo los de nuestra app
        // Cambiar a [CrowdBLE.serviceUUID] si solo quieres tu app específica
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        // Notificar cambio de estado vía closure (asegurando main)
        DispatchQueue.main.async { [weak self] in
            if let isScanning = self?.isScanning {
                self?.onScanStateChange?(isScanning)
            }
        }
    }

    private func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false

        NotificationCenter.default.post(name: .crowdScanDidFinish, object: nil,
                                        userInfo: ["count": nearbyCount])

        // Notificar fin de escaneo vía closure
        DispatchQueue.main.async { [weak self] in
            self?.onScanStateChange?(false)
        }
    }

    private func startAdvertising() {
        guard !isAdvertising else {
            print("Already advertising, skipping.")
            return
        }
        guard peripheral.state == .poweredOn else {
            print("Peripheral not powered on, cannot advertise. State: \(peripheral.state.rawValue)")
            lastError = "Peripheral manager not ready. State: \(peripheral.state.rawValue)"
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
            }
            return
        }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "SUMAQ",
            CBAdvertisementDataServiceUUIDsKey: [CrowdBLE.serviceUUID]
        ]
        peripheral.startAdvertising(advertisementData)
        // isAdvertising se confirmará en peripheralManagerDidStartAdvertising
    }

    private func stopAdvertising() {
        guard isAdvertising else { return }
        peripheral.stopAdvertising()
        isAdvertising = false

        // Notificar cambio de advertising vía closure
        DispatchQueue.main.async { [weak self] in
            self?.onAdvertisingStateChange?(false)
        }
    }
}

extension CrowdController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            lastError = nil
            if pendingScan {
                // Si el peripheral también está listo, iniciamos advertising
                if peripheral.state == .poweredOn {
                    startAdvertising()
                }
                startScan()
                pendingScan = false
            }
        case .unauthorized:
            lastError = "Bluetooth permission denied. Please enable in Settings."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
        case .unsupported:
            lastError = "Bluetooth unsupported on this device."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
        case .poweredOff:
            lastError = "Bluetooth is turned off. Please turn it on."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
        case .resetting:
            lastError = "Bluetooth is resetting. Please wait..."
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
            }
        case .unknown:
            // Estado de inicialización, no es error.
            break
        @unknown default:
            lastError = "Unknown Bluetooth state. Please try again."
            pendingScan = false
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onScanStateChange?(false)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        let rssiValue = RSSI.intValue
        // Umbral configurable por tu proyecto
        guard rssiValue > CrowdBLE.rssiCloseThreshold else { return }

        if seen.insert(peripheral.identifier).inserted {
            nearbyCount = seen.count

            NotificationCenter.default.post(
                name: .crowdScanDidUpdate,
                object: nil,
                userInfo: ["count": nearbyCount]
            )

            // Notificar cambio de conteo vía closure (asegurando main)
            // Log para verificar el thread donde se ejecuta el delegate method
            print("[THREAD CHECK] didDiscover called on thread: \(Thread.current)")
            DispatchQueue.main.async { [weak self] in
                print("[THREAD CHECK] onCountChange closure executing on thread: \(Thread.current)")
                if let count = self?.nearbyCount {
                    self?.onCountChange?(count)
                }
            }
        }
    }
}

extension CrowdController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if !isAdvertising && pendingScan {
                startAdvertising()
            }
        case .unauthorized:
            lastError = "Bluetooth permission denied. Please enable in Settings."
            stop()
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onAdvertisingStateChange?(false)
            }
        case .unsupported:
            lastError = "Bluetooth advertising is not supported on this device."
            stop()
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onAdvertisingStateChange?(false)
            }
        case .poweredOff:
            lastError = "Bluetooth is turned off. Please turn it on to use this feature."
            stop()
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onAdvertisingStateChange?(false)
            }
        case .resetting:
            lastError = "Bluetooth is resetting. Please wait..."
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
            }
        case .unknown:
            // Estado de inicialización, no es error.
            break
        @unknown default:
            lastError = "Unknown Bluetooth state. Please try again."
            DispatchQueue.main.async { [weak self] in
                if let error = self?.lastError { self?.onError?(error) }
                self?.onAdvertisingStateChange?(false)
            }
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            print("Failed to start advertising: \(error.localizedDescription)")
            lastError = "Failed to start advertising: \(error.localizedDescription)"
            isAdvertising = false
            DispatchQueue.main.async { [weak self] in
                if let msg = self?.lastError { self?.onError?(msg) }
                self?.onAdvertisingStateChange?(false)
            }
        } else {
            print("Successfully started advertising")
            isAdvertising = true
            lastError = nil
            // Notificar inicio de advertising vía closure (asegurando main)
            DispatchQueue.main.async { [weak self] in
                if let adv = self?.isAdvertising { self?.onAdvertisingStateChange?(adv) }
            }
        }
    }
}
