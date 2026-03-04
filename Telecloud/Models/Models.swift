
import Foundation

// MARK: - Telegram Models

struct TelegramUpdate: Codable {
    let updateId: Int
    let message: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

struct TelegramMessage: Codable, Identifiable {
    let messageId: Int
    let date: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?
    let document: TelegramDocument?
    let audio: TelegramAudio?
    let video: TelegramVideo?
    let photo: [TelegramPhotoSize]?
    let caption: String?

    var id: Int { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case date
        case from
        case chat
        case text
        case document
        case audio
        case video
        case photo
        case caption
    }
}

struct TelegramUser: Codable {
    let id: Int
    let firstName: String
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case username
    }
}

struct TelegramChat: Codable {
    let id: Int64
    let type: String
    let title: String?
}

struct TelegramDocument: Codable {
    let fileId: String
    let fileUniqueId: String
    let fileName: String?
    let mimeType: String?
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSize = "file_size"
    }
}

struct TelegramAudio: Codable {
    let fileId: String
    let fileUniqueId: String
    let duration: Int
    let performer: String?
    let title: String?
    let mimeType: String?
    let fileSize: Int?
    let thumbnail: TelegramPhotoSize?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case duration
        case performer
        case title
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case thumbnail
    }
}

struct TelegramVideo: Codable {
    let fileId: String
    let fileUniqueId: String
    let width: Int
    let height: Int
    let duration: Int
    let fileName: String?
    let mimeType: String?
    let fileSize: Int?
    let thumbnail: TelegramPhotoSize?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case width
        case height
        case duration
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case thumbnail
    }
}

struct TelegramPhotoSize: Codable {
    let fileId: String
    let fileUniqueId: String
    let width: Int
    let height: Int
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case width
        case height
        case fileSize = "file_size"
    }
}

struct TelegramFileResponse: Codable {
    let ok: Bool
    let result: TelegramFile?
}

struct TelegramFile: Codable {
    let fileId: String
    let fileUniqueId: String
    let fileSize: Int?
    let filePath: String?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileSize = "file_size"
        case filePath = "file_path"
    }
}

// MARK: - Telecloud Models

enum FileType: String, Codable {
    case audio = "audio"
    case video = "video"
    case document = "document"
    case image = "image"
    case folder = "folder"

    var icon: String {
        switch self {
        case .audio: return "music.note"
        case .video: return "film"
        case .document: return "doc.text"
        case .image: return "photo"
        case .folder: return "folder.fill"
        }
    }

    var color: String {
        switch self {
        case .audio: return "pink"
        case .video: return "purple"
        case .document: return "blue"
        case .image: return "green"
        case .folder: return "orange"
        }
    }
}

struct TelecloudFolder: Codable, Identifiable {
    let id: String
    var name: String
    let parentId: String?
    let createdAt: Date
    let updatedAt: Date
}

struct TelecloudFile: Codable, Identifiable {
    let id: String
    let messageId: Int
    let folderId: String?
    let filename: String
    let fileType: FileType
    let fileId: String
    let fileSize: Int64
    let mimeType: String?
    let createdAt: Date
    let updatedAt: Date
    let metadata: FileMetadata?
}

struct FileMetadata: Codable {
    let duration: Int?  // For audio/video
    let width: Int?     // For images/video
    let height: Int?    // For images/video
    let performer: String?  // For audio
    let title: String?      // For audio
}

struct TelecloudIndex: Codable {
    var folders: [TelecloudFolder]
    var files: [TelecloudFile]
    var lastSyncDate: Date?
    var version: Int

    init() {
        self.folders = []
        self.files = []
        self.lastSyncDate = nil
        self.version = 1
    }
}

struct MediaItem: Identifiable, Equatable {
    let id: String
    let file: TelecloudFile
    let downloadURL: URL?
    let localURL: URL?
    let artwork: Data?

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case type = "Type"
}
