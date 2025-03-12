//
//  GoogleDriveQuotaChecker.swift
//  gSync
//
//  Created by 0000 on 13.03.2025.
//

import Foundation

/// Модуль для проверки квоты хранения на Google Drive.
/// Отвечает за запрос и анализ доступного пространства.
final class GoogleDriveQuotaChecker {
    private let driveService: GoogleDriveInterface
    
    init(driveService: GoogleDriveInterface = GoogleDriveService.shared) {
        self.driveService = driveService
    }
    
    /// Проверяет квоту хранения и возвращает результат через completion.
    /// - Parameter completion: Обработчик результата с общей, использованной и свободной памятью или ошибкой.
    func checkQuota(completion: @escaping (Result<(total: Int64, used: Int64, free: Int64), Error>) -> Void) {
        driveService.checkStorageQuota { result in
            switch result {
            case .success(let (total, used)):
                let free = total - used
                print("Quota: Total = \(total) bytes, Used = \(used) bytes, Free = \(free) bytes")
                completion(.success((total, used, free)))
            case .failure(let error):
                print("Failed to check quota: \(error)")
                completion(.failure(error))
            }
        }
    }
}
