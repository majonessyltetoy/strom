import SwiftUI

@main
struct stromApp: App {
    @AppStorage("simulateBMS") var simulateBMS: Bool = false
    var bleController = BLEController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, Font.body.monospacedDigit())
                .environmentObject(bleController)
                .background(Color.yellow)
                .onAppear {
                    simulateBMS = false
                }
        }
    }
}


