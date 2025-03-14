import Foundation

/// Структура для представления узла в иерархии удалённых папок (например, с Google Drive, Dropbox и т.д.).
/// - Логика: Этот модуль моделирует удалённую папку в облачном хранилище как структуру данных с идентификатором, именем и опциональным списком дочерних папок. Используется в основном для отображения структуры папок в пользовательском интерфейсе (например, в `FolderSelectionView`) и передачи данных между модулями, такими как `GoogleDriveService` и `SyncOrchestrator`. Реализует протоколы `Identifiable` и `Codable` для интеграции с SwiftUI и сериализации/десериализации JSON.
/// - Особенности: Простая и неизменяемая структура данных, не содержит бизнес-логики. Зависит только от Foundation. Поддерживает рекурсивную иерархию через опциональное поле `children`. Отсутствие дополнительных метаданных (например, размера или даты модификации) делает её минималистичной, что может быть как плюсом (простота), так и минусом (ограниченная функциональность).
/// - Архитектурные мысли: Как архитектор, я вижу, что структура хорошо подходит для текущей задачи отображения иерархии, но может быть расширена для поддержки дополнительных атрибутов (например, `size`, `lastModified`), если потребуется синхронизация метаданных. Отсутствие методов обработки данных оставляет всю логику на внешних модулях, что соответствует принципу разделения ответственности, но может усложнить тестирование или расширение без изменения структуры.
struct RemoteFolder: Identifiable, Codable {
    
    /// Уникальный идентификатор удалённой папки.
    /// - Используется для соответствия протоколу `Identifiable` и идентификации папки в облачном хранилище.
    let id: String
    
    /// Имя удалённой папки.
    /// - Отображается в пользовательском интерфейсе и используется для сопоставления с локальными папками.
    let name: String
    
    /// Опциональный массив дочерних удалённых папок.
    /// - Позволяет строить рекурсивную иерархию папок; `nil` для папок без вложенных элементов.
    let children: [RemoteFolder]?
    
    /// Перечисление ключей для кодирования и декодирования структуры в JSON.
    /// - Определяет соответствие между свойствами структуры и ключами в JSON-данных.
    enum CodingKeys: String, CodingKey {
        case id // Ключ для свойства `id`
        case name // Ключ для свойства `name`
        case children // Ключ для свойства `children`
    }
}
