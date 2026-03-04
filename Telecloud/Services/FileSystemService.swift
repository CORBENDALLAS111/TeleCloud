
import Foundation
import Combine

class FileSystemService: ObservableObject {
    static let shared = FileSystemService()

    @Published var index: TelecloudIndex
    @Published var currentFolderId: String? = nil
    @Published var currentPath: [TelecloudFolder] = []

    private let telegramService = TelegramService.shared
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var indexURL: URL {
        documentsURL.appendingPathComponent("telecloud_index.json")
    }

    private var cacheURL: URL {
        let url = documentsURL.appendingPathComponent("cache", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private init() {
        self.index = FileSystemService.loadIndex()
        updateCurrentPath()
    }

    // MARK: - Index Management

    private static func loadIndex() -> TelecloudIndex {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let indexURL = documentsURL.appendingPathComponent("telecloud_index.json")

        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(TelecloudIndex.self, from: data) else {
            return TelecloudIndex()
        }
        return index
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL)
        }
    }

    func syncWithTelegram() -> AnyPublisher<Void, Error> {
        guard let chatId = telegramService.chatId else {
            return Fail(error: NSError(domain: "FileSystemService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])).eraseToAnyPublisher()
        }

        return telegramService.getChatMessages(chatId: chatId)
            .map { [weak self] messages -> Void in
                guard let self = self else { return }
                self.processMessages(messages)
                self.saveIndex()
                return
            }
            .eraseToAnyPublisher()
    }

    private func processMessages(_ messages: [TelegramMessage]) {
        for message in messages {
            // Check if file already exists
            if index.files.contains(where: { $0.messageId == message.messageId }) {
                continue
            }

            var fileId: String?
            var fileName: String?
            var fileType: FileType?
            var fileSize: Int64 = 0
            var mimeType: String?
            var metadata: FileMetadata?

            if let audio = message.audio {
                fileId = audio.fileId
                fileName = audio.title ?? audio.fileUniqueId
                fileType = .audio
                fileSize = Int64(audio.fileSize ?? 0)
                mimeType = audio.mimeType
                metadata = FileMetadata(
                    duration: audio.duration,
                    width: nil,
                    height: nil,
                    performer: audio.performer,
                    title: audio.title
                )
            } else if let video = message.video {
                fileId = video.fileId
                fileName = message.caption ?? video.fileName ?? "video_\(message.messageId)"
                fileType = .video
                fileSize = Int64(video.fileSize ?? 0)
                mimeType = video.mimeType
                metadata = FileMetadata(
                    duration: video.duration,
                    width: video.width,
                    height: video.height,
                    performer: nil,
                    title: nil
                )
            } else if let document = message.document {
                fileId = document.fileId
                fileName = document.fileName ?? "document_\(message.messageId)"
                fileType = determineFileType(mimeType: document.mimeType, fileName: document.fileName)
                fileSize = Int64(document.fileSize ?? 0)
                mimeType = document.mimeType
                metadata = nil
            } else if let photos = message.photo, let photo = photos.last {
                fileId = photo.fileId
                fileName = message.caption ?? "image_\(message.messageId).jpg"
                fileType = .image
                fileSize = Int64(photo.fileSize ?? 0)
                mimeType = "image/jpeg"
                metadata = FileMetadata(
                    duration: nil,
                    width: photo.width,
                    height: photo.height,
                    performer: nil,
                    title: nil
                )
            }

            if let fileId = fileId, let type = fileType {
                let file = TelecloudFile(
                    id: UUID().uuidString,
                    messageId: message.messageId,
                    folderId: currentFolderId,
                    filename: fileName ?? "unnamed_\(message.messageId)",
                    fileType: type,
                    fileId: fileId,
                    fileSize: fileSize,
                    mimeType: mimeType,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(message.date)),
                    updatedAt: Date(),
                    metadata: metadata
                )
                index.files.append(file)
            }
        }

        index.lastSyncDate = Date()
    }

    private func determineFileType(mimeType: String?, fileName: String?) -> FileType {
        if let mime = mimeType {
            if mime.hasPrefix("audio/") { return .audio }
            if mime.hasPrefix("video/") { return .video }
            if mime.hasPrefix("image/") { return .image }
        }
        if let name = fileName {
            let ext = (name as NSString).pathExtension.lowercased()
            if ["mp3", "m4a", "aac", "wav", "flac"].contains(ext) { return .audio }
            if ["mp4", "mov", "avi", "mkv"].contains(ext) { return .video }
            if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) { return .image }
        }
        return .document
    }

    // MARK: - Folder Operations

    func createFolder(name: String) {
        let folder = TelecloudFolder(
            id: UUID().uuidString,
            name: name,
            parentId: currentFolderId,
            createdAt: Date(),
            updatedAt: Date()
        )
        index.folders.append(folder)
        saveIndex()
    }

    func deleteFolder(id: String) {
        index.folders.removeAll { $0.id == id }
        // Move files to parent or root
        index.files = index.files.map { file in
            if file.folderId == id {
                var updated = file
                // This is a simplified approach - in production you'd want to handle this better
                return updated
            }
            return file
        }
        saveIndex()
    }

    func renameFolder(id: String, newName: String) {
        if let index = index.folders.firstIndex(where: { $0.id == id }) {
            index.folders[index].name = newName
            index.folders[index].updatedAt = Date()
            saveIndex()
        }
    }

    func navigateToFolder(id: String?) {
        currentFolderId = id
        updateCurrentPath()
    }

    func navigateUp() {
        if let current = index.folders.first(where: { $0.id == currentFolderId }),
           let parentId = current.parentId {
            currentFolderId = parentId
        } else {
            currentFolderId = nil
        }
        updateCurrentPath()
    }

    private func updateCurrentPath() {
        var path: [TelecloudFolder] = []
        var currentId = currentFolderId

        while let id = currentId,
              let folder = index.folders.first(where: { $0.id == id }) {
            path.insert(folder, at: 0)
            currentId = folder.parentId
        }

        currentPath = path
    }

    // MARK: - File Operations

    func getFilesInCurrentFolder() -> [TelecloudFile] {
        return index.files.filter { $0.folderId == currentFolderId }
    }

    func getFoldersInCurrentFolder() -> [TelecloudFolder] {
        return index.folders.filter { $0.parentId == currentFolderId }
    }

    func moveFile(fileId: String, toFolderId: String?) {
        if let index = index.files.firstIndex(where: { $0.id == fileId }) {
            // Create new file with updated folder
            var updatedFile = index.files[index]
            // Since folderId is let, we need to recreate
            let newFile = TelecloudFile(
                id: updatedFile.id,
                messageId: updatedFile.messageId,
                folderId: toFolderId,
                filename: updatedFile.filename,
                fileType: updatedFile.fileType,
                fileId: updatedFile.fileId,
                fileSize: updatedFile.fileSize,
                mimeType: updatedFile.mimeType,
                createdAt: updatedFile.createdAt,
                updatedAt: Date(),
                metadata: updatedFile.metadata
            )
            index.files[index] = newFile
            saveIndex()
        }
    }

    func deleteFile(id: String) {
        index.files.removeAll { $0.id == id }
        saveIndex()
    }

    func renameFile(id: String, newName: String) {
        if let index = index.files.firstIndex(where: { $0.id == id }) {
            let oldFile = index.files[index]
            let newFile = TelecloudFile(
                id: oldFile.id,
                messageId: oldFile.messageId,
                folderId: oldFile.folderId,
                filename: newName,
                fileType: oldFile.fileType,
                fileId: oldFile.fileId,
                fileSize: oldFile.fileSize,
                mimeType: oldFile.mimeType,
                createdAt: oldFile.createdAt,
                updatedAt: Date(),
                metadata: oldFile.metadata
            )
            index.files[index] = newFile
            saveIndex()
        }
    }

    // MARK: - Download Management

    func getLocalFileURL(for file: TelecloudFile) -> URL? {
        let localURL = cacheURL.appendingPathComponent(file.id)
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }
        return nil
    }

    func downloadFile(_ file: TelecloudFile) -> AnyPublisher<URL, Error> {
        let localURL = cacheURL.appendingPathComponent(file.id)

        if fileManager.fileExists(atPath: localURL.path) {
            return Just(localURL)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        return telegramService.getFile(fileId: file.fileId)
            .flatMap { [weak self] telegramFile -> AnyPublisher<Data, Error> in
                guard let filePath = telegramFile.filePath else {
                    return Fail(error: NSError(domain: "FileSystemService", code: 404, userInfo: [NSLocalizedDescriptionKey: "File path not found"])).eraseToAnyPublisher()
                }
                return self?.telegramService.downloadFile(filePath: filePath) ?? Empty().eraseToAnyPublisher()
            }
            .map { data -> URL in
                try? data.write(to: localURL)
                return localURL
            }
            .eraseToAnyPublisher()
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheURL)
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }

    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = attributes.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
}
