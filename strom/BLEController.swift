import Foundation
import CoreBluetooth

class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var batchThrottler = BatchThrottler(interval: 1.0)
    private var rssiTimer: Timer?
    private var connectionTimeout: DispatchWorkItem?
    private var firstConnect = true
//    private var attemptingReconnect = false
    @Published var bmsController: BMSController?
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var connectingPeripheral: CBPeripheral?
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown
    
    private let bmsServiceUUID = CBUUID(string: "FFF0")
    private let writeCharacteristicUUID = CBUUID(string: "FFF3")

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    func handleDiscoveredPeripheral(_ peripheral: CBPeripheral, rssi: NSNumber) {
        batchThrottler.queueAction(for: peripheral) { [weak self] in
            self?.updateDiscoveredPeripherals(peripheral, rssi: rssi)
        }
    }

    private func updateDiscoveredPeripherals(_ peripheral: CBPeripheral, rssi: NSNumber) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = discoveredPeripherals.firstIndex(where: { $0.id == peripheral.identifier }) {
                discoveredPeripherals[index].latestRSSI = rssi
            } else {
                let newPeripheral = DiscoveredPeripheral(peripheral: peripheral, latestRSSI: rssi)
                discoveredPeripherals.append(newPeripheral)
                Logger.shared.log("new peripheral " + (peripheral.name ?? ""))
            }
        }
    }
    
    func toggleBMSDummy(_ toggle: Bool) {
        if toggle {
            bmsController = DummyBMSController(bleController: self)
        } else {
            disconnectPeripheral()
        }
    }
    
    private func startMonitoringRSSI() {
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.connectedPeripheral?.state == .connected {
                self.connectedPeripheral?.readRSSI()
            }
        }
        if connectedPeripheral?.state == .connected {
            connectedPeripheral?.readRSSI()
        }
    }

    private func stopMonitoringRSSI() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    func startScanning() {
        if centralManager.state != .poweredOn {
            return
        }
        batchThrottler.clean()
        discoveredPeripherals = []
        if let peripheral = connectedPeripheral, isConnected {
            discoveredPeripherals.append(DiscoveredPeripheral(peripheral: peripheral, latestRSSI: 0))
            startMonitoringRSSI()
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        Logger.shared.log("Started scanning")
    }
    
    func stopScanning() {
        if bluetoothState == .poweredOn {
            centralManager.stopScan()
        }
        batchThrottler.clean()
        stopMonitoringRSSI()
        isScanning = false
        Logger.shared.log("Stop scanning")
    }
    
    func connect(to peripheral: CBPeripheral) {
        if isConnecting {
            return
        }
        if connectedPeripheral != nil {
            disconnectPeripheral()
        }
        firstConnect = false
        isConnecting = true
//        attemptingReconnect = false
        connectingPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        startConnectionTimeout(for: peripheral)
        Logger.shared.log("Connect to " + (peripheral.name ?? ""))
    }
    
    private func startConnectionTimeout(for peripheral: CBPeripheral) {
        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if peripheral.state != .connected {
                // Connection attempt timed out. Cancelling attempt.
                isConnecting = false
//                attemptingReconnect = false
                connectingPeripheral = nil
                self.centralManager.cancelPeripheralConnection(peripheral)
                Logger.shared.log("Cancel connection, timeout")
            } else if !isConnected {
                // Connected, but BMS neither accepted or refused unlock
                disconnectPeripheral()
                Logger.shared.log("Disconnect connection, timeout")
            }
        }
        connectionTimeout?.cancel()
        connectionTimeout = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutItem)
    }
    
    func disconnectPeripheral() {
        UserDefaults.standard.setValue(false, forKey: "simulateBMS")
        isConnecting = false
        isConnected = false
//        attemptingReconnect = false
        bmsController = nil
        connectionTimeout?.cancel()
        guard let peripheral = connectedPeripheral else {
            return
        }
        if centralManager.state == .poweredOn && peripheral.state == .connected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        Logger.shared.log("Disconnected from " + (peripheral.name ?? ""))
    }
    
    func bmsDidConnect() {
        isConnecting = false
        isConnected = true
        connectionTimeout?.cancel()
        UserDefaults.standard.setValue(connectedPeripheral?.name ?? "", forKey: "lastBMSConnection")
        Logger.shared.log("BMS unlocked " + (connectedPeripheral?.name ?? ""))
    }
    
    func sendData(_ data: Data) {
        guard let peripheral = connectedPeripheral else {
            return
        }
        guard let characteristic = writeCharacteristic else {
            return
        }
        if peripheral.state != .connected {
//            if attemptingReconnect {
//                print("RECONNECTING not sending command")
//                return
//            }
            disconnectPeripheral()
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        Logger.shared.log((peripheral.name ?? "") + " tx ", data: data)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if bluetoothState == .poweredOn {
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let deviceName = peripheral.name else { return }
        
        let defaults = UserDefaults.standard
        if firstConnect && defaults.bool(forKey: "autoReconnect") && deviceName == defaults.string(forKey: "lastBMSConnection")  {
            connect(to: peripheral)
        }
        
        if defaults.bool(forKey: "filterDevicePrefix") && !deviceName.hasPrefix("DXB-") {
            return
        }
        
        handleDiscoveredPeripheral(peripheral, rssi: RSSI)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            Logger.shared.log("No services in " + (peripheral.name ?? ""))
            disconnectPeripheral()
            return
        }
        Logger.shared.log("Found service:")
        for service in services {
            Logger.shared.log(service.uuid.uuidString)
        }
        Logger.shared.log("End service")
        if let service = services.first(where: {$0.uuid == bmsServiceUUID}) {
            peripheral.discoverCharacteristics(nil, for: service)
        } else {
            disconnectPeripheral()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            disconnectPeripheral()
            return
        }
        Logger.shared.log("In service: " + service.uuid.uuidString + " found characteristic:")
        for characteristic in characteristics {
            Logger.shared.log(characteristic.uuid.uuidString)
            if characteristic.properties.contains(.notify) {
                Logger.shared.log("contains notify")
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.write) {
                Logger.shared.log("contains write")
            }
            if characteristic.uuid == writeCharacteristicUUID {
                writeCharacteristic = characteristic
            }
        }
        Logger.shared.log("End characteristic")
        if writeCharacteristic != nil {
            bmsController = BMSController(bleController: self, deviceName: peripheral.name ?? "", isDummy: false)
        } else {
            Logger.shared.log("No write characteristic found")
            disconnectPeripheral()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        if attemptingReconnect {
//            attemptingReconnect = false
//            guard let bmsController = bmsController else {
//                disconnectPeripheral()
//                return
//            }
//            
//            if !bmsController.sendUnlock() {
//                print("failed unlock")
//                disconnectPeripheral()
//            }
//            return
//        }
        connectingPeripheral = nil
        writeCharacteristic = nil
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        Logger.shared.log("BT connect: " + (peripheral.name ?? ""))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral == peripheral {
//            if let bmsController = self.bmsController, error != nil && isConnected {
//                // attempt a quick reconnect
//                print("attempting reconnect")
//                attemptingReconnect = true
//                bmsController.stopSendingCommands()
//                centralManager.connect(peripheral, options: nil)
//                startConnectionTimeout(for: peripheral)
//                return
//            }
            disconnectPeripheral()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral == peripheral {
            disconnectPeripheral()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else {
            return
        }
        handleDiscoveredPeripheral(peripheral, rssi: RSSI)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
        
        Logger.shared.log((peripheral.name ?? "") + " rx ", data: data)
        
        if let bmsController = bmsController {
            bmsController.receivedData(data)
        }
    }
}

// Throttle updating bluetooth device list
class BatchThrottler {
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private var timer: Timer?
    
    private var actionQueue: [UUID: () -> Void] = [:]

    init(interval: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
        self.interval = interval
        self.queue = queue
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.executeActions()
        }
    }

    func queueAction(for peripheral: CBPeripheral, action: @escaping () -> Void) {
        queue.async { [weak self] in
            self?.actionQueue[peripheral.identifier] = action
        }
    }

    private func executeActions() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.actionQueue.values.forEach { $0() }
            self.actionQueue.removeAll()
        }
    }
    
    func clean() {
        self.actionQueue.removeAll()
    }
}
