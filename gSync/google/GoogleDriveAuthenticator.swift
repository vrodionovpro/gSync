//
//  GoogleDriveAuthenticator.swift
//  gSync
//
//  Created by 0000 on 13.03.2025.
//

import Foundation

/// Модуль для авторизации в Google Drive.
/// Отвечает только за проверку и установку соединения с Google Drive API.
final class GoogleDriveAuthenticator {
    private let driveService: GoogleDriveInterface
    
    init(driveService: GoogleDriveInterface = GoogleDriveService.shared) {
        self.driveService = driveService
    }
    
    /// Выполняет авторизацию и возвращает результат.
    /// - Returns: `true` при успешной авторизации, иначе `false`.
    func authenticate() -> Bool {
        let success = driveService.authenticate()
        print("Authentication \(success ? "successful" : "failed")")
        return success
    }
}
