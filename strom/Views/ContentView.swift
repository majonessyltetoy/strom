import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleController: BLEController
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack (alignment: .top) {
            TabContentView(selectedTab: $selectedTab)
            
            TopIconBar(selectedTab: $selectedTab, isConnected: bleController.isConnected)
        }
    }
}

struct TabContentView: View {
    @EnvironmentObject var bleController: BLEController
    @AppStorage("autoSwitchState") var autoSwitchState: Bool = false
    @AppStorage("simulateBMS") var simulateBMS: Bool = false
    @Binding var selectedTab: Int
    let notifyGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BluetoothView()
                .tag(0)
            if bleController.isConnected || simulateBMS {
                InfoView()
                    .tag(1)
                DashView()
                    .tag(2)
            }
            SettingsView()
                .tag(3)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: bleController.isConnected) { _, isConnected in
            notifyGenerator.notificationOccurred(isConnected ? .success : .warning)
            if autoSwitchState {
                selectedTab = isConnected ? 1 : 0
            } else if !isConnected && (selectedTab == 1 || selectedTab == 2) {
                selectedTab = 0
            }
        }
    }
}

struct TopIconBar: View {
    @AppStorage("simulateBMS") var simulateBMS: Bool = false
    @Binding var selectedTab: Int
    var isConnected: Bool
    
    var body: some View {
        HStack {
            TabButton(iconName: "phone.connection", tab: 0, selectedTab: $selectedTab)
            
            Spacer()
            
            TabButton(iconName: "info.circle",
                      tab: 1,
                      selectedTab: $selectedTab,
                      isActive: (isConnected || simulateBMS))
                .disabled(!isConnected && !simulateBMS)
            
            TabButton(iconName: "heat.element.windshield",
                      tab: 2,
                      selectedTab: $selectedTab,
                      isActive: (isConnected || simulateBMS))
                .disabled(!isConnected && !simulateBMS)
            
            Spacer()
            
            TabButton(iconName: "gear", tab: 3, selectedTab: $selectedTab)
        }
        .padding()
        .frame(height: 60)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(gradient: Gradient(colors: [.white.opacity(0.1),
                                                       .gray.opacity(0.1)]),
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

struct TabButton: View {
    var iconName: String
    var tab: Int
    @Binding var selectedTab: Int
    var isActive: Bool = true
    
    var body: some View {
        Button(action: {
            selectedTab = tab
        }) {
            Image(systemName: iconName)
                .imageScale(.large)
                .font(.system(size: 20))
                .foregroundColor(selectedTab == tab ? .accentColor : (isActive ? .primary : .secondary))
        }
    }
}
