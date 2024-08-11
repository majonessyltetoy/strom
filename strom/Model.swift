import Foundation
import CoreBluetooth

struct DiscoveredPeripheral: Identifiable {
    let peripheral: CBPeripheral
    var latestRSSI: NSNumber
    var id: UUID {
        peripheral.identifier
    }
}

struct BMSLegacyInfo1: Equatable {
    let voltage: Int16
    let current: Int16
    let fullCharge: Int16
    let remainingCharge: Int16
    let percentage: Int
}

struct BMSLegacyInfo2: Equatable {
    let factoryCapacity: Int16
    let temperatures: [Double]
}

struct BMSInfo: Equatable {
    let voltage: Int32
    let current: Int32
    let percentage: Int
    let remainingCharge: Int32
    let fullCharge: Int32
    let factoryCapacity: Int32
    let temperatures: [Double]
    
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.paddingCharacter = " "
        formatter.maximumFractionDigits = 0
        formatter.formatWidth = 4
        return formatter
    }()
    
    static let tempFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.decimalSeparator = "."
        return formatter
    }()
    
    func state() -> String {
        if current == 0 {
            return "Idle"
        } else if current > 0 {
            return "Charging"
        } else {
            return "Discharging"
        }
    }
    
    func amp() -> String {
        return BMSInfo.formatter.string(for: abs(Double(current) / 1000.0)) ?? "-"
    }
    
    func volt() -> String {
        return BMSInfo.formatter.string(for: abs(Double(voltage) / 1000.0)) ?? "-"
    }
    
    func watt() -> String {
        let volt = Double(voltage) / 1000.0
        let amp = Double(current) / 1000.0
        let power = abs(volt * amp)
        
        return BMSInfo.formatter.string(for: power) ?? "-"
    }
    
    func chargeTime() -> String {
        guard current != 0 else { return "-" }
        
        let difference: Double
        if current > 0 {
            difference = Double(fullCharge - remainingCharge) / Double(current)
        } else {
            difference = Double(remainingCharge) / Double(abs(current))
        }
        
        let hours = Int(difference)
        let minutes = Int((difference - Double(hours)) * 60)
        
        return String(format: "%dh %dm", abs(hours), abs(minutes))
    }
    
    func getTemps() -> [String] {
        let userTempUnit = UserDefaults.standard.string(forKey: "temperatureUnit")
        let getTempUnit: UnitTemperature
        if userTempUnit == UnitTemperature.fahrenheit.symbol {
            getTempUnit = UnitTemperature.fahrenheit
        } else {
            getTempUnit = UnitTemperature.celsius
        }
        return temperatures.map { kelvin in
            let kelvinMeasurement = Measurement(value: kelvin, unit: UnitTemperature.kelvin)
            let outputMeasurement = kelvinMeasurement.converted(to: getTempUnit)
            return BMSInfo.tempFormatter.string(from: outputMeasurement)
        }
    }
}

struct BMSCellVolts: Equatable {
    let cellVoltages: [Int]
    var highValue: Int {
        return cellVoltages.max() ?? 0
    }
    var lowValue: Int {
        return cellVoltages.min() ?? 0
    }
}

enum OpCode: UInt8 {
    case unlockAccepted = 0x32
    case unlockRejected = 0x33
    case legacyInfo1 = 0x60
    case legacyInfo2 = 0x61
    case cellVolt = 0x62
    case unlock = 0x64
    case unlocked = 0x65
    case getInfo = 0xa0
}
