
import Foundation
import Combine

class TelegramService: ObservableObject {
    static let shared = TelegramService()

    @Published var isAuthenticated = false
    @Published var botToken: String = ""
    @Published var chatId: Int64?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://api.telegram.org/bot"
    private var cancellables = Set<AnyCancellable>()
    private let session = URLSession.shared

    private init() {
        loadCredentials()
    }

    // MARK: - Authentication

    func authenticate(token: String, chatId: Int64) -> AnyPublisher<Bool, Error> {
        self.botToken = token
        self.chatId = chatId

        return verifyBot()
            .flatMap { [weak self] isValid -> AnyPublisher<Bool, Error> in
                guard let self = self, isValid else {
                    return Just(false)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }

                self.isAuthenticated = true
                self.saveCredentials()
                return Just(true)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    func verifyBot() -> AnyPublisher<Bool, Error> {
        let url = URL(string: "\(baseURL)\(botToken)/getMe")!

        return session.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: TelegramResponse.self, decoder: JSONDecoder())
            .map { $0.ok }
            .catch { _ in Just(false).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
    }

    // MARK: - Messages

    func getUpdates(offset: Int? = nil, limit: Int = 100) -> AnyPublisher<[TelegramUpdate], Error> {
        var urlString = "\(baseURL)\(botToken)/getUpdates?limit=\(limit)"
        if let offset = offset {
            urlString += "&offset=\(offset)"
        }

        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UpdatesResponse.self, decoder: JSONDecoder())
            .map { $0.result ?? [] }
            .eraseToAnyPublisher()
    }

    func getChatMessages(chatId: Int64) -> AnyPublisher<[TelegramMessage], Error> {
        // Get updates and filter by chat
        return getUpdates()
            .map { updates in
                updates.compactMap { update in
                    guard let message = update.message,
                          message.chat.id == chatId else { return nil }
                    return message
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - File Operations

    func getFile(fileId: String) -> AnyPublisher<TelegramFile, Error> {
        let urlString = "\(baseURL)\(botToken)/getFile?file_id=\(fileId)"
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: TelegramFileResponse.self, decoder: JSONDecoder())
            .compactMap { $0.result }
            .eraseToAnyPublisher()
    }

    func downloadFile(filePath: String) -> AnyPublisher<Data, Error> {
        let urlString = "https://api.telegram.org/file/bot\(botToken)/\(filePath)"
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    func sendMessage(text: String, chatId: Int64) -> AnyPublisher<TelegramMessage, Error> {
        let urlString = "\(baseURL)\(botToken)/sendMessage"
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ] as [String: Any]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: MessageResponse.self, decoder: JSONDecoder())
            .compactMap { $0.result }
            .eraseToAnyPublisher()
    }

    // MARK: - Persistence

    private func saveCredentials() {
        UserDefaults.standard.set(botToken, forKey: "botToken")
        if let chatId = chatId {
            UserDefaults.standard.set(chatId, forKey: "chatId")
        }
    }

    private func loadCredentials() {
        if let token = UserDefaults.standard.string(forKey: "botToken"),
           let chatId = UserDefaults.standard.object(forKey: "chatId") as? Int64 {
            self.botToken = token
            self.chatId = chatId
            self.isAuthenticated = true
        }
    }

    func logout() {
        botToken = ""
        chatId = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "botToken")
        UserDefaults.standard.removeObject(forKey: "chatId")
    }

    // MARK: - Response Types

    struct TelegramResponse: Codable {
        let ok: Bool
    }

    struct UpdatesResponse: Codable {
        let ok: Bool
        let result: [TelegramUpdate]?
    }

    struct MessageResponse: Codable {
        let ok: Bool
        let result: TelegramMessage?
    }
}
