import Foundation

class DummyBMSController: BMSController {
    private var updateTimer: Timer?
    
    override var bmsInfo: BMSInfo? {
        didSet {
            dataReceivedSignal = !dataReceivedSignal
        }
    }

    init(bleController: BLEController) {
        super.init(bleController: bleController, deviceName: "Dummy Device", isDummy: true)
        startUpdatingValues()
    }
    
    deinit {
        stopUpdatingValues()
    }
    
    private func startUpdatingValues() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateValues()
        }
    }
    
    private func stopUpdatingValues() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc private func updateValues() {
        bmsInfo = BMSInfo(voltage: Int32.random(in: 55000...56000),
                          current: Int32.random(in: -8000...7000),
                          percentage: Int.random(in: 80...100),
                          remainingCharge: Int32.random(in: 15000...20000),
                          fullCharge: Int32.random(in: 15000...20000),
                          factoryCapacity: 200000,
                          temperatures: [Double.random(in: 285.0...295.0),
                                         Double.random(in: 285.0...295.0),
                                         Double.random(in: 285.0...295.0)])

        bmsCellVolts = BMSCellVolts(cellVoltages: (0..<14).map { _ in Int.random(in: 3400...3500) })
    }
}
