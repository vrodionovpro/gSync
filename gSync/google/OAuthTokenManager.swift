import Foundation
import AppKit

/// Управляет OAuth-токенами для основного аккаунта.
final class OAuthTokenManager {
    static let shared = OAuthTokenManager()
    private let config = EnvironmentConfig.shared
    private let credentialsPath: String
    private let oauthConfigPath: String

    private init() {
        self.credentialsPath = config.credentialsPath
        self.oauthConfigPath = config.oauthConfigPath
    }

    /// Проверяет валидность OAuth-токена и обновляет его при необходимости.
    func ensureValidToken(completion: @escaping (Bool) -> Void) {
        let quotaScript = config.pythonQuotaScriptPath
        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = [quotaScript, credentialsPath]
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
            }
        }

        task.waitUntilExit()
        outputHandle.readabilityHandler = nil

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        let success = task.terminationStatus == 0

        if !success && (output?.contains("invalid_grant") == true || !FileManager.default.fileExists(atPath: credentialsPath)) {
            print("OAuth token is invalid, expired, or credentials file is missing. Initiating re-authentication...")
            refreshOAuthToken(completion: completion)
        } else {
            completion(success)
        }
    }

    /// Запускает процесс обновления OAuth-токена через браузер.
    private func refreshOAuthToken(completion: @escaping (Bool) -> Void) {
        let scriptPath = URL(fileURLWithPath: config.pythonQuotaScriptPath)
            .deletingLastPathComponent()
            .appendingPathComponent("get_oauth_token.py")
            .path

        let task = Process()
        task.launchPath = "/usr/bin/python3"
        task.arguments = [scriptPath, oauthConfigPath, credentialsPath]
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
                    print(outputString)
                }
            }
        }

        task.waitUntilExit()
        outputHandle.readabilityHandler = nil

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        let success = task.terminationStatus == 0

        if success {
            print("OAuth token refreshed successfully. New credentials saved to \(credentialsPath)")
        } else {
            let errorMessage = output ?? "unknown error"
            print("Failed to refresh OAuth token: \(errorMessage)")
        }
        completion(success)
    }
}
