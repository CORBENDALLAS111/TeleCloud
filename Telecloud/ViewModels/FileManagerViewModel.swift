
import Foundation
import Combine

class FileManagerViewModel: ObservableObject {
    @Published var files: [TelecloudFile] = []
    @Published var folders: [TelecloudFolder] = []
    @Published var viewMode: ViewMode = .grid
    @Published var sortOption: SortOption = .name
    @Published var searchQuery: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFiles: Set<String> = []
    @Published var isSelectionMode = false

    private let fileSystemService = FileSystemService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        refreshData()
    }

    private func setupBindings() {
        fileSystemService.$currentFolderId
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        var files = fileSystemService.getFilesInCurrentFolder()
        var folders = fileSystemService.getFoldersInCurrentFolder()

        // Apply search filter
        if !searchQuery.isEmpty {
            files = files.filter { $0.filename.localizedCaseInsensitiveContains(searchQuery) }
            folders = folders.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }

        // Apply sorting
        switch sortOption {
        case .name:
            files.sort { $0.filename.localizedCompare($1.filename) == .orderedAscending }
            folders.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .date:
            files.sort { $0.createdAt > $1.createdAt }
            folders.sort { $0.createdAt > $1.createdAt }
        case .size:
            files.sort { $0.fileSize > $1.fileSize }
        case .type:
            files.sort { $0.fileType.rawValue < $1.fileType.rawValue }
        }

        self.files = files
        self.folders = folders
    }

    func sync() {
        isLoading = true
        errorMessage = nil

        fileSystemService.syncWithTelegram()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.refreshData()
                }
            )
            .store(in: &cancellables)
    }

    func createFolder(name: String) {
        fileSystemService.createFolder(name: name)
        refreshData()
    }

    func deleteFolder(id: String) {
        fileSystemService.deleteFolder(id: id)
        refreshData()
    }

    func renameFolder(id: String, newName: String) {
        fileSystemService.renameFolder(id: id, newName: newName)
        refreshData()
    }

    func navigateToFolder(id: String?) {
        fileSystemService.navigateToFolder(id: id)
    }

    func navigateUp() {
        fileSystemService.navigateUp()
    }

    func deleteFile(id: String) {
        fileSystemService.deleteFile(id: id)
        refreshData()
    }

    func renameFile(id: String, newName: String) {
        fileSystemService.renameFile(id: id, newName: newName)
        refreshData()
    }

    func moveFile(fileId: String, toFolderId: String?) {
        fileSystemService.moveFile(fileId: fileId, toFolderId: toFolderId)
        refreshData()
    }

    func toggleSelection(for fileId: String) {
        if selectedFiles.contains(fileId) {
            selectedFiles.remove(fileId)
        } else {
            selectedFiles.insert(fileId)
        }
    }

    func selectAll() {
        selectedFiles = Set(files.map { $0.id })
    }

    func deselectAll() {
        selectedFiles.removeAll()
    }

    func deleteSelected() {
        for id in selectedFiles {
            fileSystemService.deleteFile(id: id)
        }
        selectedFiles.removeAll()
        isSelectionMode = false
        refreshData()
    }

    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
