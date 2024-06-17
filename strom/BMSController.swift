import CoreBluetooth

class BMSController: ObservableObject {
    
    var bleController: BLEController
    private let pageLength = 20
    private var isReceivingMultiple = false
    private var failedAttempts = 0
    private var dataBuffer = Data()
    private var cmdTimer: DispatchSourceTimer?
    private var cmdIndex = 0
    private let commands: [OpCode] = [.getInfo, .cellVolt]
    
    @Published var deviceName: String
    @Published var bmsInfo: BMSInfo?
    @Published var bmsCellVolts: BMSCellVolts?
//    @Published var bmsInfoPoints: [BMSInfo] = []
//    @Published var bmsCellVoltPoints: [BMSCellVolts] = []
    @Published var errorSignal: Bool = false
    @Published var dataReceivedSignal: Bool = false
    
    init(bleController: BLEController, deviceName: String, isDummy: Bool) {
        self.bleController = bleController
        self.deviceName = deviceName
        if isDummy {
            bleController.bmsDidConnect()
        } else {
            if !sendUnlock() {
                bleController.disconnectPeripheral()
            }
        }
    }
    
    func sendCommand(opCode: OpCode, data: [UInt8]) {
        var command = [UInt8]()
        command.append(opCode.rawValue)
        command.append(contentsOf: [0x00, 0x00]) // padding
        command.append(contentsOf: data)
        // checksum is (sum of bytes + 8)
        let checksum = (command.reduce(0, { $0 + UInt($1) }) + 8)
        let cs1 = UInt8(checksum >> 8)
        let cs2 = UInt8(checksum & 0xFF)
        command.append(contentsOf: [cs1, cs2]) // checksum
        command.append(contentsOf: [0x0D, 0x0A]) // footer (CR LF)
        
        // header
        command.insert(contentsOf: [0x3A, 0x03, 0x05], at: 0)
        let pageByte = UInt8(0x11) // always page 1 of 1
        let lengthByte = UInt8(command.count)
        command.insert(contentsOf: [lengthByte, pageByte], at: 0)
        
        // end padding
        command += Array(repeating: 0x00, count: pageLength-command.count)
        bleController.sendData(Data(command))
    }
    
    func sendUnlock() -> Bool {
        guard let id = UInt16(deviceName.suffix(4), radix: 16) else {
            return false
        }
        let pw1 = UInt8(id >> 8)
        let pw2 = UInt8(id & 0xFF)
        sendCommand(opCode: .unlock, data: [pw1, pw2])
        return true
    }
    
    // We could use async await instead of timer and schedule
    func startSendingCommands() {
        let queue = DispatchQueue(label: (Bundle.main.bundleIdentifier ?? "app") + ".timer")
        cmdTimer = DispatchSource.makeTimerSource(queue: queue)
        
        cmdTimer?.schedule(deadline: .now(), repeating: 0.3)
        
        cmdTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if isReceivingMultiple {
                // timeout waiting for all the pages
                if failedAttempts < 5 {
                    failedAttempts += 1
                    return
                }
            }
            failedAttempts = 0
            sendCommand(opCode: commands[cmdIndex], data: [])
            cmdIndex = (cmdIndex + 1) % commands.count
        }
        
        cmdTimer?.resume()
    }
    
    func stopSendingCommands() {
        cmdTimer?.cancel()
        cmdTimer = nil
    }
    
    func receivedData(_ data: Data) {
        guard let firstByte = data.first else {
            return
        }
        // ignore ACK response
        // most siginificant nibble is always 0x8
        if (firstByte >> 4) == 0x8 {
            return
        }
        var ack = data
        ack[0] |= 0x80
        // Send ACK
        bleController.sendData(ack)
        // process respons
        collectPages(data: data)
    }
    
    private func collectPages(data: Data) {
        guard data.count == self.pageLength else {
            return
        }
        let lengthByte = Int(data[0])+2
        let pageByte = Int(data[1] >> 4)
        let maxPages = Int(data[1] & 0x0F)
        let pageData = data.subdata(in: 2..<lengthByte)

        if pageByte == 1 {
            if isReceivingMultiple && dataBuffer != pageData {
                errorSignal = !errorSignal
            }
            isReceivingMultiple = maxPages > 1
            dataBuffer = pageData
        } else {
            dataBuffer.append(pageData)
        }

        if pageByte == maxPages {
            isReceivingMultiple = false
            // remove header and footer
            dataBuffer = dataBuffer.subdata(in: 3..<(dataBuffer.count - 2))
            // check if checksum match
            let checkData = dataBuffer.subdata(in: dataBuffer.count-2..<dataBuffer.count)
            let checksum = Int(checkData[0]) << 8 | Int(checkData[1])
            dataBuffer = dataBuffer.subdata(in: 0..<dataBuffer.count-2)
            if checksum != dataBuffer.reduce(0, { $0 + UInt($1) }) + 8 {
                errorSignal = !errorSignal
                return
            }
            dataReceivedSignal = !dataReceivedSignal
            parseResponse(data: dataBuffer)
        }
    }

    private func parseResponse(data: Data) {
        let opCode = OpCode(rawValue: data[0])
        switch opCode {
        case .unlockAccepted, .unlock, .unlocked:
            bleController.bmsDidConnect()
            startSendingCommands()
        case .unlockRejected:
            bleController.disconnectPeripheral()
        case .getInfo:
            let voltage = bytesToInt32(data, startingAt: 3)
            let current = bytesToInt32(data, startingAt: 7)
            let percentage = Int(data[15])
            let remainingCharge = bytesToInt32(data, startingAt: 16)
            let fullCharge = bytesToInt32(data, startingAt: 20)
            let factoryCapacity = bytesToInt32(data, startingAt: 24)
            let temp1 = bytesToTemp(data, startingAt: 28)
            let temp2 = bytesToTemp(data, startingAt: 30)
            let temp3 = bytesToTemp(data, startingAt: 32)
            bmsInfo = BMSInfo(voltage: voltage,
                              current: current,
                              percentage: percentage,
                              remainingCharge: remainingCharge,
                              fullCharge: fullCharge,
                              factoryCapacity: factoryCapacity,
                              temp1: temp1,
                              temp2: temp2,
                              temp3: temp3)
        case .cellVolt:
            let numberOfCells = Int(data[3])
            var cellVoltages: [Int] = []
            var highValue = Int.min
            var lowValue = Int.max
            for i in 0..<numberOfCells {
                let index = (i * 2) + 4
                let voltageValue = (Int(data[index]) << 8) | Int(data[index + 1])
                if voltageValue < lowValue {
                    lowValue = voltageValue
                }
                if voltageValue > highValue {
                    highValue = voltageValue
                }
                cellVoltages.append(voltageValue)
            }
            bmsCellVolts = BMSCellVolts(highValue: highValue,
                                        lowValue: lowValue,
                                        cellVoltages: cellVoltages)
        case .none:
            bleController.disconnectPeripheral()
        }
    }
    
    private func bytesToInt32(_ data: Data, startingAt index: Int) -> Int32 {
        let result = Int32(data[index + 0]) << 24 |
                     Int32(data[index + 1]) << 16 |
                     Int32(data[index + 2]) << 8 |
                     Int32(data[index + 3])
        return result
    }
    
    private func bytesToTemp(_ data: Data, startingAt index: Int) -> String {
        let value = Int(data[index]) << 8 | Int(data[index + 1])
        let tempInKelvin = Double(value) / 10.0
        
        let userTempUnit = UserDefaults.standard.string(forKey: "temperatureUnit")
        
        if userTempUnit == UnitTemperature.fahrenheit.symbol {
            return formatTemperature(tempInKelvin, to: .fahrenheit)
        } else {
            return formatTemperature(tempInKelvin, to: .celsius)
        }
    }
    
    private func formatTemperature(_ kelvin: Double, to outputUnit: UnitTemperature) -> String {
        let kelvinMeasurement = Measurement(value: kelvin, unit: UnitTemperature.kelvin)
        let outputMeasurement = kelvinMeasurement.converted(to: outputUnit)
        
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.decimalSeparator = "."

        return formatter.string(from: outputMeasurement)
    }
}
