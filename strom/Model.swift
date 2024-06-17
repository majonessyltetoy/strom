import Foundation
import CoreBluetooth

struct DiscoveredPeripheral: Identifiable {
    let peripheral: CBPeripheral
    var latestRSSI: NSNumber
    var id: UUID {
        peripheral.identifier
    }
}

struct BMSInfo: Equatable {
    let voltage: Int32
    let current: Int32
    let percentage: Int
    let remainingCharge: Int32
    let fullCharge: Int32
    let factoryCapacity: Int32
    let temp1: String
    let temp2: String
    let temp3: String
    
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.paddingCharacter = " "
        formatter.maximumFractionDigits = 0
        formatter.formatWidth = 4
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
//        return String(difference)
        //return BMSInfo.formatter.string(for: difference) ?? "-"
    }
}

struct BMSCellVolts: Equatable {
    let highValue: Int
    let lowValue: Int
    let cellVoltages: [Int]
}

enum OpCode: UInt8 {
    case unlockAccepted = 0x32
    case unlockRejected = 0x33
    case cellVolt = 0x62
    case unlock = 0x64
    case unlocked = 0x65
    case getInfo = 0xa0
}
