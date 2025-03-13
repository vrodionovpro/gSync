import SwiftUI

struct FolderSelectionView: View {
    @State private var folders: [RemoteFolder] = []
    @State private var selectedFolderId: String = ""
    @EnvironmentObject var driveManager: SyncOrchestrator
    var localFolderId: UUID?
    var localFolderPath: String

    var body: some View {
        VStack {
            Text("Local Folder: \(localFolderPath)")
                .font(.headline)
                .padding(.top, 10)
                .padding(.bottom, 5)

            if folders.isEmpty {
                Text("No folders available")
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
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

                        ForEach(folders) { folder in
                            FolderRow(folder: folder, selectedFolderId: $selectedFolderId, level: 0)
                        }
                    }
                    .padding()
                }
            }
            Button("Confirm") {
                print("Confirm button pressed, selectedFolderId: \(selectedFolderId), localFolderId: \(String(describing: localFolderId))")
                if !selectedFolderId.isEmpty {
                    UserDefaults.standard.set(selectedFolderId, forKey: "LastSelectedFolderId")
                    driveManager.setFolderId(selectedFolderId, localFolderId: localFolderId)
                    NSApplication.shared.keyWindow?.close()
                } else {
                    print("No folder selected")
                }
            }
            .disabled(folders.isEmpty)
        }
        .frame(width: 300, height: 400)
        .onAppear {
            loadFolders()
            if let lastSelectedFolderId = UserDefaults.standard.string(forKey: "LastSelectedFolderId") {
                selectedFolderId = lastSelectedFolderId
            }
        }
    }

    private func loadFolders() {
        DispatchQueue.global(qos: .background).async {
            let loadedFolders = driveManager.fetchFolders()
            DispatchQueue.main.async {
                self.folders = loadedFolders
                let rootCount = loadedFolders.count
                let totalCount = loadedFolders.reduce(0) { $0 + (1 + ($1.children?.count ?? 0)) }
                let sampleNames = loadedFolders.prefix(3).map { $0.name }.joined(separator: ", ")
                print("Loaded folders: \(rootCount) root folder(s), \(totalCount) total folder(s) (e.g., \(sampleNames))")
            }
        }
    }
}

struct FolderRow: View {
    let folder: RemoteFolder
    @Binding var selectedFolderId: String
    let level: Int
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if folder.children != nil && !folder.children!.isEmpty {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.clear)
                        .frame(width: 16)
                }

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

            if isExpanded, let children = folder.children, !children.isEmpty {
                ForEach(children) { child in
                    FolderRow(folder: child, selectedFolderId: $selectedFolderId, level: level + 1)
                }
            }
        }
    }
}
