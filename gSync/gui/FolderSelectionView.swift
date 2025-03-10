import SwiftUI

/// Представление для выбора папки на Google Drive.
/// Отображает иерархию папок в виде дерева и позволяет выбрать папку для загрузки.
struct FolderSelectionView: View {
    @State private var folders: [RemoteFolder] = [] // Список корневых папок
    @State private var selectedFolderId: String = "" // Выбранный ID папки
    @EnvironmentObject var driveManager: GoogleDriveManager // Менеджер для работы с Google Drive
    var localFolderId: UUID? // Идентификатор локальной папки
    var localFolderPath: String // Путь к локальной папке для отображения

    var body: some View {
        VStack {
            // Отображаем путь к локальной папке вверху
            Text("Local Folder: \(localFolderPath)")
                .font(.headline)
                .padding(.top, 10)
                .padding(.bottom, 5)

            if folders.isEmpty {
                Text("No folders available")
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        // Корневая папка
                        Button(action: {
                            selectedFolderId = ""
                        }) {
                            HStack {
                                Text("Root")
                                Spacer()
                                if selectedFolderId == "" {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.leading, 10)
                        }
                        .foregroundColor(selectedFolderId == "" ? .blue : .primary)

                        // Дерево папок
                        ForEach(folders) { folder in
                            FolderRow(folder: folder, selectedFolderId: $selectedFolderId, level: 0)
                        }
                    }
                    .padding()
                }
            }
            // Кнопка для подтверждения выбора
            Button("Confirm") {
                print("Confirm button pressed, selectedFolderId: \(selectedFolderId)") // Логируем выбор
                if !selectedFolderId.isEmpty {
                    // Сохраняем выбранный folderId в UserDefaults
                    UserDefaults.standard.set(selectedFolderId, forKey: "LastSelectedFolderId")
                    // Запускаем загрузку
                    driveManager.setFolderId(selectedFolderId, localFolderId: localFolderId)
                    // Закрываем окно
                    NSApplication.shared.keyWindow?.close()
                } else {
                    print("No folder selected")
                }
            }
            .disabled(folders.isEmpty)
        }
        .frame(width: 300, height: 400)
        .onAppear {
            loadFolders() // Загружаем папки при появлении
            // Загружаем последнюю выбранную папку из UserDefaults
            if let lastSelectedFolderId = UserDefaults.standard.string(forKey: "LastSelectedFolderId") {
                selectedFolderId = lastSelectedFolderId
            }
        }
    }

    /// Загружает список папок с Google Drive и выводит сжатую информацию.
    private func loadFolders() {
        folders = driveManager.service.fetchFolders()
        let rootCount = folders.count
        let totalCount = folders.reduce(0) { $0 + (1 + ($1.children?.count ?? 0)) } // Примерное количество
        let sampleNames = folders.prefix(3).map { $0.name }.joined(separator: ", ")
        print("Loaded folders: \(rootCount) root folder(s), \(totalCount) total folder(s) (e.g., \(sampleNames))") // Сжатый вывод
    }
}

/// Рекурсивное представление для отображения папки и её дочерних папок.
struct FolderRow: View {
    let folder: RemoteFolder
    @Binding var selectedFolderId: String
    let level: Int // Уровень вложенности для отступа
    @State private var isExpanded: Bool = false // Состояние свёрнутости папки

    var body: some View {
        VStack(alignment: .leading) {
            // Текущая папка с треугольником
            HStack {
                // Треугольник для разворачивания/сворачивания
                if folder.children != nil && !folder.children!.isEmpty {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Пустое место, если нет дочерних папок
                    Image(systemName: "chevron.right")
                        .foregroundColor(.clear)
                        .frame(width: 16)
                }

                // Кнопка для выбора папки
                Button(action: {
                    selectedFolderId = folder.id
                }) {
                    HStack {
                        Text(String(repeating: "  ", count: level) + folder.name)
                        Spacer()
                        if selectedFolderId == folder.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .foregroundColor(selectedFolderId == folder.id ? .blue : .primary)
            }

            // Дочерние папки (показываем только если развёрнуто)
            if isExpanded, let children = folder.children, !children.isEmpty {
                ForEach(children) { child in
                    FolderRow(folder: child, selectedFolderId: $selectedFolderId, level: level + 1)
                }
            }
        }
    }
}
