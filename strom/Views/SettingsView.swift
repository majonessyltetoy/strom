import SwiftUI
import MessageUI

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
                    .onChange(of: autoReconnect) { _, newValue in
                        Logger.shared.log("Auto Reconnect changed to \(newValue ? "On" : "Off")")
                    }
                Divider()
                Toggle("Switch view on connect", isOn: $autoSwitchState)
                    .onChange(of: autoSwitchState) { _, newValue in
                        Logger.shared.log("Auto Switch State changed to \(newValue ? "On" : "Off")")
                    }
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
                .onChange(of: filterDevicePrefix) { _, newValue in
                    Logger.shared.log("Filter Device Prefix changed to \(newValue ? "On" : "Off")")
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
            .onChange(of: temperatureUnit) { _, newValue in
                Logger.shared.log("Temperature Unit changed to \(newValue)")
            }
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
    @State private var showingMailComposer = false
    @State private var showAlert = false
    private let alertMessage = "Mail services are not available on this device."
    
    var body: some View {
        Section(content: {
            VStack {
                Toggle("Dummy BMS device", isOn: $simulateBMS)
                    .onChange(of: simulateBMS) { _, newValue in
                        Logger.shared.log("Simulate BMS changed to \(newValue)")
                        if newValue {
                            bleController.toggleBMSDummy(true)
                        } else {
                            bleController.toggleBMSDummy(false)
                        }
                    }
                Divider()
                HStack{
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        } else {
                            showAlert = true
                        }
                    }) {
                        Text("Send debug log")
                    }
                    .sheet(isPresented: $showingMailComposer) {
                        MailComposer(emailContent: "", attachmentURL: Logger.shared.logFileURL)
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }, header: {
            Text("Debug")
                .fontWeight(.light)
                .padding(.horizontal)
        })
    }
}

struct MailComposer: UIViewControllerRepresentable {
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposer

        init(_ parent: MailComposer) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }

    var emailContent: String
    var attachmentURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject("Strom debug log")
        vc.setMessageBody(emailContent, isHTML: false)
        vc.setToRecipients(["bjorn.lamo@icloud.com"])

        if let attachmentURL = attachmentURL {
            if let fileData = try? Data(contentsOf: attachmentURL) {
                vc.addAttachmentData(fileData, mimeType: "text/plain", fileName: "app.log")
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
