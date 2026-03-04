
import SwiftUI

struct SettingsView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var fileSystemService = FileSystemService.shared
    @State private var showingLogoutConfirmation = false
    @State private var showingClearCacheConfirmation = false

    var cacheSize: String {
        let size = fileSystemService.getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                Section(header: Text("Account").foregroundColor(.purple)) {
                    HStack {
                        Text("Bot")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                    }

                    Button(role: .destructive, action: {
                        showingLogoutConfirmation = true
                    }) {
                        Text("Disconnect")
                    }
                }

                Section(header: Text("Storage").foregroundColor(.purple)) {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.gray)
                    }

                    Button(action: {
                        showingClearCacheConfirmation = true
                    }) {
                        Text("Clear Cache")
                            .foregroundColor(.orange)
                    }
                }

                Section(header: Text("About").foregroundColor(.purple)) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.1")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .alert("Disconnect?", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                authViewModel.logout()
            }
        } message: {
            Text("You will need to reconnect with your bot token to use the app again.")
        }
        .alert("Clear Cache?", isPresented: $showingClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                fileSystemService.clearCache()
            }
        } message: {
            Text("This will delete all downloaded files. They can be re-downloaded from Telegram.")
        }
    }
}
