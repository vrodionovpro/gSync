import SwiftUI

class StatusOverlay: ObservableObject {
    static let shared = StatusOverlay() // Добавляем синглтон
    @Published var isVisible = false
    @Published var message = ""
    @Published var progress: Double = 0.0

    private init() {
        // Приватный инициализатор, чтобы гарантировать использование только shared
    }

    func show(message: String, duration: TimeInterval = 2.0) {
        self.message = message
        self.isVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.isVisible = false
        }
    }

    func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = min(max(progress, 0.0), 1.0)
        }
    }

    func bindToStatusItem() {
        let statusItem = MenuManager.shared.menuStatusItem
        if let button = statusItem.button {
            print("Привязка к статус-бару выполнена для кнопки: \(button)")
        } else {
            print("Ошибка: Кнопка статус-бара не найдена")
        }
    }

    func showWithProgress(message: String, progress: Double) {
        self.message = message
        self.isVisible = true
        self.updateProgress(progress)
    }
}
