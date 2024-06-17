import SwiftUI

struct DashView: View {
    @EnvironmentObject var bleController: BLEController
    
    var body: some View {
        if let bmsController = bleController.bmsController {
            VStack {
                Spacer()
                    .frame(height: 60)
                
                HStack{
                    VStack(alignment: .leading) {
                        Section(content: {
                            BatteryView(bmsController: bmsController)
                        }, header: {
                            Text("Battery")
                                .fontWeight(.light)
                                .padding(.horizontal)
                        })
                    }
                    
                    Spacer()
                        .frame(maxWidth: 100)
                    
                    VStack(alignment: .leading) {
                        Section(content: {
                            StatusView(bmsController: bmsController)
                        }, header: {
                            Text("Status")
                                .fontWeight(.light)
                                .padding(.horizontal)
                        })
                    }
                }
                
                Spacer()
                    .frame(height: 20)
                
                VStack(alignment: .leading) {
                    Section(content: {
                        PowerView(bmsController: bmsController)
                    }, header: {
                        Text("Power")
                            .fontWeight(.light)
                            .padding(.horizontal)
                            .frame(alignment: .leading)
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
        }
    }
}

struct BatteryView: View {
    @ObservedObject var bmsController: BMSController
    
    var body: some View {
        if let bmsInfo = bmsController.bmsInfo {
            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 108, height: 58)
                        .foregroundStyle(.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.secondary, lineWidth: 2))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: CGFloat(bmsInfo.percentage), height: 50)
                        .foregroundStyle(getBatteryColor(for: bmsInfo.percentage))
                        .offset(x: 4)
                    
                    HStack {
                        Spacer()
                        Text("\(bmsInfo.percentage)%")
                            .font(.title2)
                        Spacer()
                    }
                    .frame(width: 108)
                }
                
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .rotationEffect(.degrees(180))
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary)
                    .offset(x: -4)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func getBatteryColor(for percentage: Int) -> Color {
        if percentage >= 80 {
            return Color.green
        } else if percentage >= 50 {
            return Color.yellow
        } else if percentage >= 20 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

struct StatusView: View {
    @ObservedObject var bmsController: BMSController
    
    var body: some View {
        if let bmsInfo = bmsController.bmsInfo {
            VStack {
                HStack {
                    Text("State:")
                    Spacer()
                    Text("\(bmsInfo.state())")
                }
                
                Divider()
                
                HStack {
                    Text("Time:")
                    Spacer()
                    Text("\(bmsInfo.chargeTime())")
                }
            }
            .padding()
            .frame(width: 180, height: 90)
            .fixedSize()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct PowerView: View {
    @ObservedObject var bmsController: BMSController
    
    var body: some View {
        if let bmsInfo = bmsController.bmsInfo {
            VStack {
                Text("\(bmsInfo.watt())W")
                    .font(.title)
                    .monospaced()
                    .padding(.horizontal)
                
                Spacer()
                    .frame(height: 10)
                
                HStack {
                    Text("\(bmsInfo.volt())V")
                        .font(.caption)
                        .monospaced()
                    
                    
                    Text("\(bmsInfo.amp())A")
                        .font(.caption)
                        .monospaced()
                }
            }
            .padding()
            .frame(width: 180, height: 90)
            .fixedSize()
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
