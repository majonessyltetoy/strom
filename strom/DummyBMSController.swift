class DummyBMSController: BMSController {
    init(bleController: BLEController) {
        super.init(bleController: bleController, deviceName: "Dummy Device", isDummy: true)
    }
    
    override var bmsInfo: BMSInfo? {
        get {
            return BMSInfo(voltage: 55350,
                           current: -7467,
                           percentage: 85,
                           remainingCharge: 18276,
                           fullCharge: 15974,
                           factoryCapacity: 200000,
                           temp1: "14.80°C",
                           temp2: "14.90°C",
                           temp3: "18.30°C")
        }
        set {}
    }
    
    override var bmsCellVolts: BMSCellVolts? {
        get {
            return BMSCellVolts(highValue: 3465,
                                lowValue: 3398,
                                cellVoltages: [3465, 3435, 3398,
                                              3412, 3465, 3411,
                                              3450, 3399, 3451,
                                              3444, 3428, 3460,
                                              3411, 3429])
        }
        set {}
    }
}
