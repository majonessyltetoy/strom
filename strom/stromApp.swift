import SwiftUI

@main
struct stromApp: App {
    @AppStorage("simulateBMS") var simulateBMS: Bool = false
    var bleController = BLEController()
    
    init() {
        Logger.shared.log((Bundle.main.bundleIdentifier ?? "") +
                          " " +
                          (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
        registerDefaults()
        logUserSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, Font.body.monospacedDigit())
                .environmentObject(bleController)
                .onAppear {
                    simulateBMS = false
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: DefaultSettings.defaults)
    }
    
    private func logUserSettings() {
        let autoReconnect = UserDefaults.standard.bool(forKey: DefaultSettings.autoReconnect)
        let autoSwitchState = UserDefaults.standard.bool(forKey: DefaultSettings.autoSwitchState)
        let filterDevicePrefix = UserDefaults.standard.bool(forKey: DefaultSettings.filterDevicePrefix)
        let temperatureUnit = UserDefaults.standard.string(forKey: DefaultSettings.temperatureUnit)
        
        Logger.shared.log("Auto Reconnect: \(autoReconnect ? "On" : "Off")")
        Logger.shared.log("Auto Switch State: \(autoSwitchState ? "On" : "Off")")
        Logger.shared.log("Filter Device Prefix: \(filterDevicePrefix ? "On" : "Off")")
        Logger.shared.log("Temperature Unit: \(temperatureUnit ?? "Not set")")
    }
}


