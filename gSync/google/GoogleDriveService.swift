import Foundation

class GoogleDriveService: GoogleDriveInterface {
    static let shared = GoogleDriveService()
    private let config = EnvironmentConfig.shared
    private let serviceAccountPath: String

    private init() {
        self.serviceAccountPath = config.serviceAccountPath
        print("GoogleDriveService initialized")
        clearAuthCache() // Очищаем кэш токенов при инициализации
    }

    /// Очищает кэш авторизации, если он существует.
    private func clearAuthCache() {
        // Предполагается, что Python-скрипт не кэширует токены локально.
        // Если кэш есть (например, в ~/.cache/), можно добавить удаление:
        let cachePath = NSHomeDirectory() + "/.cache/google-auth"
        if FileManager.default.fileExists(atPath: cachePath) {
            try? FileManager.default.removeItem(atPath: cachePath)
            print("Cleared Google auth cache at \(cachePath)")
        }
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

        outputHandle.readabilityHandler = { handle in
            let newData = handle.availableData
            if newData.count > 0 {
                outputData.append(newData)
                if let outputString = String(data: newData, encoding: .utf8) {
                    print("Received raw data: \(outputString)")
                    let lines = outputString.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        print("Processed line: \(line)")
                        progressHandler(line)
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
        let (output, success) = runPythonScript(config.pythonAuthScriptPath, arguments: [serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output.replacingOccurrences(of: "ya29.*", with: "[REDACTED]", options: .regularExpression))")
        }
        print("Authentication \(success ? "successful" : "failed")")
        return success
    }

    func listFiles() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFilesScriptPath, arguments: [serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        return success
    }

    func calculateMD5(filePath: String) -> Bool {
        let (output, success) = runPythonScript(config.pythonMD5ScriptPath, arguments: [filePath]) { _ in }
        if let output = output {
            print("MD5 calculation output: \(output)")
        }
        return success
    }

    func uploadFile(filePath: String, fileName: String, folderId: String?, progressHandler: ((String) -> Void)?, completion: @escaping (Bool) -> Void) {
        guard let folderId = folderId else {
            print("No folder ID provided")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let (checkOutput, checkSuccess) = runPythonScript(config.pythonCheckFileExistsScriptPath, arguments: [serviceAccountPath, fileName, folderId]) { progress in
            progressHandler?(progress)
        }
        if let checkOutput = checkOutput, checkOutput.contains("already exists") {
            print("Skipping upload: File \(fileName) already exists in folder \(folderId)")
            DispatchQueue.main.async { completion(false) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let (output, success) = self.runPythonScript(self.config.pythonUploadScriptPath, arguments: [self.serviceAccountPath, filePath, fileName, folderId]) { progress in
                progressHandler?(progress)
            }
            if let output = output {
                print("Python output: \(output)")
            }
            DispatchQueue.main.async { completion(success) }
        }
    }

    func listFolders() -> Bool {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [serviceAccountPath]) { _ in }
        if let output = output {
            print("Python output: \(output)")
        }
        return success
    }

    func fetchFolders() -> [RemoteFolder] {
        let (output, success) = runPythonScript(config.pythonListFoldersScriptPath, arguments: [serviceAccountPath]) { _ in }
        guard success, let output = output, let jsonData = output.data(using: .utf8) else {
            print("Failed to fetch folders")
            return []
        }

        do {
            let folders = try JSONDecoder().decode([RemoteFolder].self, from: jsonData)
            return folders
        } catch {
            print("Failed to decode folders: \(error)")
            return []
        }
    }

    func checkFileExistsByMD5(md5: String, folderId: String) -> Bool {
        let (output, success) = runPythonScript(config.pythonCheckMD5ScriptPath, arguments: [serviceAccountPath, md5, folderId]) { _ in }
        if let output = output {
            print("MD5 check output: \(output)")
        }
        return success && output?.contains("already exists") == true
    }

    func checkStorageQuota(completion: @escaping (Result<(total: Int64, used: Int64), Error>) -> Void) {
        let (output, success) = runPythonScript(config.pythonQuotaScriptPath, arguments: [serviceAccountPath]) { _ in }
        guard success, let output = output, let jsonData = output.data(using: .utf8) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch quota"])))
            return
        }

        do {
            let quota = try JSONDecoder().decode([String: Int64].self, from: jsonData)
            guard let total = quota["total"], let used = quota["used"] else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid quota data"])
            }
            completion(.success((total, used)))
        } catch {
            completion(.failure(error))
        }
    }

    func uploadFileInChunks(filePath: String, fileName: String, folderId: String, chunkSize: Int64, startOffset: Int64, totalSize: Int64, sessionUri: String?, progressHandler: @escaping (Int64, Int64, String?) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        let args = [serviceAccountPath, filePath, fileName, folderId, String(chunkSize), String(startOffset), String(totalSize), sessionUri ?? "None"]
        DispatchQueue.global(qos: .userInitiated).async {
            let (output, success) = self.runPythonScript(self.config.pythonUploadScriptPath, arguments: args) { progress in
                if progress.hasPrefix("PROGRESS:") {
                    let components = progress.split(separator: " ")
                    if components.count >= 2, let percent = Int(components[0].replacingOccurrences(of: "PROGRESS:", with: "").replacingOccurrences(of: "%", with: "")) {
                        let uploadedBytes = Int64(Double(totalSize) * Double(percent) / 100.0)
                        let uri = components.last?.hasPrefix("SESSION_URI:") == true ? String(components.last!.dropFirst(12)) : sessionUri
                        progressHandler(uploadedBytes, totalSize, uri)
                    }
                }
            }
            if success {
                completion(.success(()))
            } else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: output ?? "Unknown error"])
                completion(.failure(error))
            }
        }
    }
}
