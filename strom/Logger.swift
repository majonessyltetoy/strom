import Foundation

class Logger {
    static let shared = Logger()
    let logFileURL: URL
    private let logLimit = 5000
    private var logCount = 0
    private let logCheck = 200 // check logLimit every nth time
    
    private init() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentDirectory.appendingPathComponent("app.log")
        ensureLogFileExists()
    }
    
    private func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
    }

    func log(_ message: String) {
        let logMessage = "[\(Date())] \(message)\n"
        saveLog(logMessage)
    }
    
    func log(_ message: String, data: Data) {
        let base64String = data.base64EncodedString()
        let logMessage = "[\(Date())] \(message): \(base64String)\n"
        saveLog(logMessage)
    }

    private func saveLog(_ message: String) {
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            if let data = message.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
        logCount += 1
        if logCount > logCheck {
            manageLogFile()
            logCount = 0
        }
    }
    
    private func manageLogFile() {
        if let logContent = try? String(contentsOf: logFileURL, encoding: .utf8) {
            var logEntries = logContent.split(separator: "\n")
            if logEntries.count > logLimit {
                let excessEntries = (logEntries.count - logLimit) + (logLimit / 2)
                logEntries = Array(logEntries.dropFirst(excessEntries))
                let updatedLogContent = logEntries.joined(separator: "\n")
                try? updatedLogContent.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
