import Foundation

struct DefaultSettings {
    static let autoSwitchState = "autoSwitchState"
    static let autoReconnect = "autoReconnect"
    static let filterDevicePrefix = "filterDevicePrefix"
    static let temperatureUnit = "temperatureUnit"
    
    static let defaults: [String: Any] = [
        autoSwitchState: false,
        autoReconnect: false,
        filterDevicePrefix: true,
        temperatureUnit: UnitTemperature.celsius.symbol
    ]
}
