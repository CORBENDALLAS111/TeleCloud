
import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var botToken: String = ""
    @Published var chatId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let telegramService = TelegramService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        telegramService.$isAuthenticated
            .assign(to: &$isAuthenticated)
    }

    func login() {
        guard !botToken.isEmpty, !chatId.isEmpty else {
            errorMessage = "Please enter both Bot Token and Chat ID"
            return
        }

        guard let chatIdInt = Int64(chatId) else {
            errorMessage = "Invalid Chat ID"
            return
        }

        isLoading = true
        errorMessage = nil

        telegramService.authenticate(token: botToken, chatId: chatIdInt)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] success in
                    if !success {
                        self?.errorMessage = "Authentication failed. Please check your credentials."
                    }
                }
            )
            .store(in: &cancellables)
    }

    func logout() {
        telegramService.logout()
    }
}
