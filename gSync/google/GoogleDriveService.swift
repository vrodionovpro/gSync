import Foundation

class GoogleDriveService: GoogleDriveInterface {
    static let shared = GoogleDriveService()
    private let config = EnvironmentConfig.shared

    private init() {
        print("GoogleDriveService initialized")
    }

    private func runPythonScript(_ scriptPath: String, arguments: [String], progressHandler: @escaping (String) -> Void) -> (output: String?, success: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = [scriptPath] + arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()

        let outputHandle = pipe.fileHandleForReading
        var outputData = Data()
        let progressQueue = DispatchQueue(label: "progressQueue")

        outputHandle.readabilityHandler = { handle in
            let newData = handle.availableData
            if newData.count > 0 {
                outputData.append(newData)
                if let outputString = String(data: newData, encoding: .utf8) {
                    print("Received raw data: \(outputString)")  // Диагностика
                    let lines = outputString.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        print("Processed line: \(line)")  // Диагностика
                        if line.hasPrefix("PROGRESS:") {
                            progressHandler(line)
                        }
                    }
                }
            }
        }

        task.waitUntilExit()
        outputHandle.readabilityHandler = nil

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        let success = task.terminationStatus == 0
        return (output, success)
    }

    func authenticate() -> Bool {
        let (output, success) = runPythonScript(config.pythonAuthScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output.replacingOccurrences(of: "ya29.*", with: "[REDACTED]", options: .regularExpression))")
        }
        print("Authentication \(success ? "successful" : "failed")")
        return success
    }

    func listFiles() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFilesScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing files \(success ? "successful" : "failed")")
        return success
    }

    func calculateMD5(filePath: String) -> Bool {
        let (output, success) = runPythonScript(config.pythonMD5ScriptPath, arguments: [filePath]) { _ in }
        if let output = output {
            print("MD5 calculation output: \(output)")
        }
        print("MD5 calculation \(success ? "successful" : "failed")")
        return success
    }

    func uploadFile(filePath: String, fileName: String, folderId: String?, progressHandler: ((String) -> Void)?, completion: @escaping (Bool) -> Void) {
        guard let folderId = folderId else {
            print("No folder ID provided")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let (checkOutput, checkSuccess) = runPythonScript(config.pythonCheckFileExistsScriptPath, arguments: [config.serviceAccountPath, fileName, folderId]) { progress in
            progressHandler?(progress)
        }
        if let checkOutput = checkOutput {
            print("File existence check output: \(checkOutput)")
            if checkOutput.contains("already exists") {
                print("Skipping upload: File \(fileName) already exists in folder \(folderId)")
                DispatchQueue.main.async { completion(false) }
                return
            }
        } else if !checkSuccess {
            print("Failed to get file existence check output")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let (output, success) = self.runPythonScript(self.config.pythonUploadScriptPath, arguments: [self.config.serviceAccountPath, filePath, fileName, folderId]) { progress in
                let progressValue = progress.replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")
                print("[\(fileName)] uploading \(progressValue)%")
                progressHandler?(progress)
            }
            if let output = output {
                print("Python output: \(output)")
            }
            print("Upload \(success ? "successful" : "failed")")
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func listFolders() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        print("Listing folders \(success ? "successful" : "failed")")
        return success
    }

    func fetchFolders() -> [RemoteFolder] {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [config.serviceAccountPath]) { _ in }
        print("fetchFolders success: \(success)")
        guard success, let output = output, let jsonData = output.data(using: .utf8) else {
            print("Failed to parse folder list from Python script")
            return []
        }

        do {
            let decoder = JSONDecoder()
            let folders = try decoder.decode([RemoteFolder].self, from: jsonData)
            let rootCount = folders.count
            let totalCount = countFolders(folders)
            let sampleNames = folders.prefix(3).map { $0.name }.joined(separator: ", ")
            print("fetchFolders output: \(rootCount) root folder(s), \(totalCount) total folder(s) (e.g., \(sampleNames))")
            return folders
        } catch {
            print("Failed to decode folder hierarchy: \(error)")
            return []
        }
    }

    private func countFolders(_ folders: [RemoteFolder]) -> Int {
        var count = folders.count
        for folder in folders {
            if let children = folder.children {
                count += countFolders(children)
            }
        }
        return count
    }

    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool {
        return false
    }
}
