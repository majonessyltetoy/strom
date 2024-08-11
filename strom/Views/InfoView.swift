import SwiftUI

struct InfoView: View {
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
        ScrollView {
            if let bmsController = bleController.bmsController {
                VStack {
                    Spacer()
                        .frame(height: 60)
                    
                    ConnectionInfoView(bmsController: bmsController)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    DetailInfoView(bmsController: bmsController)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    CellInfoView(bmsController: bmsController)
                }
                .padding()
            }
        }
        .contentMargins(.top, 60, for: .scrollIndicators)
    }
}

struct ConnectionInfoView: View {
    @ObservedObject var bmsController: BMSController
    
    var body: some View {
        VStack (alignment: .leading) {
            Section(content: {
                HStack {
                    Text("\(bmsController.deviceName)")
                    Spacer()
                    BlinkerInfoView(bmsController: bmsController)
                }
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }, header: {
                Text("Connection")
                    .fontWeight(.light)
                    .padding(.horizontal)
            })
        }
    }
}

struct BlinkerInfoView: View {
    @ObservedObject var bmsController: BMSController
    @State private var dataBlink = false
    @State private var errorBlink = false
    
    var body: some View {
        ZStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(.gray)
            
            Image(systemName: "circle.fill")
                .onChange(of: bmsController.dataReceivedSignal, {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dataBlink = true
                    } completion: {
                        dataBlink = false
                    }
                })
                .foregroundStyle(.green)
                .opacity(dataBlink ? 1 : 0)
            
            Image(systemName: "circle.fill")
                .onChange(of: bmsController.errorSignal, {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        errorBlink = true
                    } completion: {
                        errorBlink = false
                    }
                })
                .foregroundStyle(.red)
                .opacity(errorBlink ? 1 : 0)
        }
    }
}

struct DetailInfoView: View {
    @ObservedObject var bmsController: BMSController

    var body: some View {
        if let bmsInfo = bmsController.bmsInfo {
            VStack(alignment: .leading) {
                DetailSectionView(header: "Basic Info", content: [
                    ("Voltage", "\(bmsInfo.voltage) mV"),
                    ("Current", "\(bmsInfo.current) mA"),
                    ("Percentage", "\(bmsInfo.percentage)%")
                ])
                
                Spacer()
                    .frame(height: 20)
                
                DetailSectionView(header: "Capacity", content: [
                    ("Remaining Charge", "\(bmsInfo.remainingCharge) mAh"),
                    ("Full Charge", "\(bmsInfo.fullCharge) mAh"),
                    ("Factory Capacity", "\(bmsInfo.factoryCapacity) mAh")
                ])
                
                Spacer()
                    .frame(height: 20)
                
                DetailSectionView(header: "Temperature", content:
                    bmsInfo.getTemps().enumerated().map { (index, temp) in
                        ("Sensor \(index + 1)", temp)
                    }
                )
            }
        } else {
            ProgressView()
        }
    }
}

struct DetailSectionView: View {
    let header: String
    var content: [(String, String)]

    var body: some View {
        Section(content: {
            VStack(alignment: .leading) {
                ForEach(Array(content.enumerated()), id: \.0) { index, item in
                    DetailRowView(label: item.0, value: item.1, addDivider: index+1 == content.count)
                }
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }, header: {
            Text(header)
                .fontWeight(.light)
                .padding(.horizontal)
        })
    }
}

struct DetailRowView: View {
    let label: String
    let value: String
    let addDivider: Bool

    var body: some View {
        VStack {
            HStack {
                Text(label + ":")
                Spacer()
                Text(value)
            }
            if !addDivider {
                Divider()
            }
        }
    }
}

struct CellInfoView: View {
    @ObservedObject var bmsController: BMSController
    
    var body: some View {
        if let bmsCellVolts = bmsController.bmsCellVolts {
            VStack {
                HStack {
                    Text("Cell Information")
                        .fontWeight(.light)
                        .padding(.horizontal)
                    Spacer()
                }
                CellMinMaxView(bmsCellVolts: bmsCellVolts)
                CellGridView(bmsCellVolts: bmsCellVolts)
            }
        } else {
            ProgressView()
        }
    }
}

struct CellMinMaxView: View {
    var bmsCellVolts: BMSCellVolts
    
    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Text("High value:")
                Spacer()
                Text("\(bmsCellVolts.highValue.formatted(.number.grouping(.never))) mV")
                    .foregroundStyle(.indigo)
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Low value:")
                Spacer()
                Text("\(bmsCellVolts.lowValue.formatted(.number.grouping(.never))) mV")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Difference:")
                Spacer()
                Text("\((bmsCellVolts.highValue - bmsCellVolts.lowValue).formatted(.number.grouping(.never))) mV")
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
            }
        }
        .fixedSize()
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CellGridView: View {
    var bmsCellVolts: BMSCellVolts
    
    let columns = [
        GridItem(),
        GridItem(),
        GridItem()
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<bmsCellVolts.cellVoltages.count, id: \.self) { index in
                VStack {
                    Text("Cell \(index + 1)")
                    Text("\(bmsCellVolts.cellVoltages[index].formatted(.number.grouping(.never))) mV")
                        .font(.footnote)
                }
                .padding()
                .fixedSize()
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(self.strokeColor(for: index), lineWidth: 3))
            }
        }
        .frame(maxWidth: 400)
    }
    
    private func strokeColor(for index: Int) -> Color {
        let value = bmsCellVolts.cellVoltages[index]
        if value == bmsCellVolts.highValue {
            return Color.indigo
        } else if value == bmsCellVolts.lowValue {
            return Color.orange
        } else {
            return Color.clear
        }
    }
}

