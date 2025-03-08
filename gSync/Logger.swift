import Foundation

class Logger {
    static let shared = Logger()
    private let logFile: URL
    private let fileQueue = DispatchQueue(label: "com.gSync.loggerQueue")

    private init() {
        logFile = URL(fileURLWithPath: "/tmp/gSync.log", isDirectory: false)
    }

    func log(_ message: String) {
        fileQueue.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            let logEntry = "\(timestamp): \(message)\n"
            if let fileHandle = try? FileHandle(forWritingTo: self.logFile) {
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                try? fileHandle.close()
            } else {
                if FileManager.default.createFile(atPath: self.logFile.path, contents: nil, attributes: nil) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFile) {
                        if let data = logEntry.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                        try? fileHandle.close()
                    }
                }
            }
        }
    }
}  
