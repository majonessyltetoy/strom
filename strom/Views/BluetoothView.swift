import SwiftUI

struct BluetoothView: View {
    @EnvironmentObject var bleController: BLEController

    var body: some View {
        VStack (alignment: .leading) {
            Spacer()
                .frame(height: 60)
            
            BluetoothBarView()
                .padding(.horizontal)
            
            DeviceListView()
        }
        .padding()
        .onAppear {
            bleController.startScanning()
        }
        .onDisappear {
            bleController.stopScanning()
        }
    }
}

struct DeviceListView: View {
    @EnvironmentObject var bleController: BLEController
    let generator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ScrollView {
            ForEach(bleController.discoveredPeripherals, id: \.id) { discoveredPeripheral in
                DeviceRow(discoveredPeripheral: discoveredPeripheral,
                          connectedPeripheralUUID: bleController.connectedPeripheral?.identifier,
                          connectingPeripheralUUID: bleController.connectingPeripheral?.identifier)
                    .onTapGesture {
                        if !bleController.isConnecting {
                            generator.impactOccurred()
                            bleController.stopScanning()
                            bleController.connect(to: discoveredPeripheral.peripheral)
                        }
                    }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DeviceRow: View {
    var discoveredPeripheral: DiscoveredPeripheral
    var connectedPeripheralUUID: UUID?
    var connectingPeripheralUUID: UUID?

    var body: some View {
        HStack {
            Text(discoveredPeripheral.peripheral.name ?? "Unknown Device")
            
            Spacer()
            
            if discoveredPeripheral.latestRSSI != 0 {
                Text("RSSI: \(discoveredPeripheral.latestRSSI)")
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
//        .background(Color.gray.opacity(discoveredPeripheral.id == connectedPeripheralUUID ||
//                                       discoveredPeripheral.id == connectingPeripheralUUID ? 0.1 : 0.0))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke((discoveredPeripheral.id == connectedPeripheralUUID ||
                     discoveredPeripheral.id == connectingPeripheralUUID ? Color.green.opacity(0.7) : Color.clear),
                    lineWidth: 2)
        )
    }
}

struct BluetoothBarView: View {
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
        HStack {
            Text("State:").fontWeight(.light)
            switch bleController.bluetoothState {
            case .poweredOn:
                switch (bleController.isConnecting, bleController.isConnected, bleController.isScanning) {
                case (true, _, _):
                    ConnectingBluetoothView(bleController: bleController)
                case (_, true, _):
                    ConnectedBluetoothView(bleController: bleController)
                case (_, _, true):
                    ScanningBluetoothView(bleController: bleController)
                default:
                    IdleBluetoothView(bleController: bleController)
                }
            default:
                Text("Not ready").fontWeight(.light)
            }
        }
    }
}

struct ConnectingBluetoothView: View {
    var bleController: BLEController
    
    var body: some View {
        HStack {
            Text("Connecting").fontWeight(.light)
            ProgressView()
            Spacer()
            Button(action: bleController.disconnectPeripheral) {
                Text("Disconnect")
            }
        }
    }
}

struct ConnectedBluetoothView: View {
    var bleController: BLEController
    
    var body: some View {
        Text("Connected").fontWeight(.light)
        Spacer()
        Button(action: bleController.disconnectPeripheral) {
            Text("Disconnect")
        }
    }
}

struct ScanningBluetoothView: View {
    var bleController: BLEController
    
    var body: some View {
        Text("Scanning").fontWeight(.light)
        ProgressView()
        Spacer()
        Button(action: bleController.stopScanning) {
            Text("Stop scanning")
        }
    }
}

struct IdleBluetoothView: View {
    var bleController: BLEController
    
    var body: some View {
        Text("Idle").fontWeight(.light)
        Spacer()
        Button(action: bleController.startScanning) {
            Text("Start scanning")
        }
    }
}
