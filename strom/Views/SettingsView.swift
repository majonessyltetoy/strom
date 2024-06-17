import SwiftUI

struct SettingsView: View {
    var body: some View {
        HStack {
            VStack (alignment: .leading) {
                Spacer()
                    .frame(height: 60)
                
                BasicSettingsView()
                
                Spacer()
                    .frame(height: 20)
                
                TemperatureSettingsView()
                
                Spacer()
                    .frame(height: 20)
                
                DebugSettingsView()
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct BasicSettingsView: View {
    @AppStorage("autoSwitchState") var autoSwitchState: Bool = false
    @AppStorage("autoReconnect") var autoReconnect: Bool = false
    @AppStorage("filterDevicePrefix") var filterDevicePrefix: Bool = true
    @State private var showAlert = false
    private let prefixInfoText = Text("""
                                        This app is made to work with Em3ev batteries. \
                                        Their device name usually start with "DXB-". \
                                        But the app may work with a generic BMS with a \
                                        different prefix.
                                        """)
    
    var body: some View {
        Section(content: {
            VStack {
                Toggle("Reconnect previous device", isOn: $autoReconnect)
                Divider()
                Toggle("Switch view on connect", isOn: $autoSwitchState)
                Divider()
                Toggle(isOn: $filterDevicePrefix) {
                    HStack {
                        Text("Filter device prefix")
                        
                        Button(action: {
                            showAlert = true
                        }) {
                            Image(systemName: "info.bubble")
                                .foregroundColor(.accentColor)
                        }
                        .alert(isPresented: $showAlert) {
                            Alert(
                                title: Text("Prefix info"),
                                message: prefixInfoText, dismissButton: .default(Text("Got it!"))
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }, header: {
            Text("Bluetooth")
                .fontWeight(.light)
                .padding(.horizontal)
        })
    }
}

struct TemperatureSettingsView: View {
    @AppStorage("temperatureUnit") var temperatureUnit: String = UnitTemperature.celsius.symbol
    
    var body: some View {
        Section(content: {
            Picker("Unit", selection: $temperatureUnit) {
                Text(UnitTemperature.celsius.symbol).tag(UnitTemperature.celsius.symbol)
                Text(UnitTemperature.fahrenheit.symbol).tag(UnitTemperature.fahrenheit.symbol)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }, header: {
            Text("Temperature Unit")
                .fontWeight(.light)
                .padding(.horizontal)
        })
    }
}

struct DebugSettingsView: View {
    @EnvironmentObject var bleController: BLEController
    @AppStorage("simulateBMS") var simulateBMS: Bool = false
    
    var body: some View {
        Section(content: {
            Toggle("Dummy BMS data", isOn: $simulateBMS)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: simulateBMS) { _, newValue in
                    if newValue {
                        bleController.toggleBMSDummy(true)
                    } else {
                        bleController.toggleBMSDummy(false)
                    }
                }
        }, header: {
            Text("Debug")
                .fontWeight(.light)
                .padding(.horizontal)
        })
    }
}
