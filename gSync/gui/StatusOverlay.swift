import AppKit

/// Слой наложения для отображения статусного текста над статусным элементом меню.
class StatusOverlay: NSView {
    private static var sharedInstance: StatusOverlay?
    private var textField: NSTextField?
    private static let overlayFrame = NSRect(x: 0, y: 0, width: 100, height: 20) // Стандартный размер

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Возвращает единственный экземпляр StatusOverlay (паттерн синглтон).
    static var shared: StatusOverlay {
        if sharedInstance == nil {
            if let statusItem = MenuManager.shared.statusItem, let button = statusItem.button {
                sharedInstance = StatusOverlay(frame: button.bounds)
                button.addSubview(sharedInstance!)
                sharedInstance?.frame = button.bounds
            } else {
                sharedInstance = StatusOverlay(frame: overlayFrame) // Фallback, если statusItem ещё не готов
            }
        }
        return sharedInstance!
    }

    private func setup() {
        // Создаём текстовое поле для отображения статуса
        textField = NSTextField(frame: bounds)
        textField?.isEditable = false
        textField?.isBezeled = false
        textField?.backgroundColor = .clear
        textField?.textColor = .white
        textField?.font = NSFont.systemFont(ofSize: 12)
        textField?.alignment = .center
        if let textField = textField {
            addSubview(textField)
        }
        updateStatus("Ready") // Устанавливаем начальный статус
    }

    /// Обновляет текст статуса.
    func updateStatus(_ status: String) {
        textField?.stringValue = status
    }
}
