
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingHelp = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.purple.opacity(0.3),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .purple.opacity(0.5), radius: 20)

                        Image(systemName: "cloud.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }

                    Text("Telecloud")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("Your Telegram Cloud Music Player")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)

                Spacer()

                // Login Form
                VStack(spacing: 20) {
                    // Bot Token
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bot Token")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)

                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.purple)

                            SecureField("Enter your bot token", text: $viewModel.botToken)
                                .foregroundColor(.white)
                                .textInputAutocapitalization(.never)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }

                    // Chat ID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chat ID")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)

                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.purple)

                            TextField("Enter group chat ID", text: $viewModel.chatId)
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Login Button
                    Button(action: {
                        viewModel.login()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Connect")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)

                Spacer()

                // Help Button
                Button(action: {
                    showingHelp = true
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("How to setup?")
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingHelp) {
            SetupHelpView()
        }
    }
}

struct SetupHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Setup Instructions")
                            .font(.title2.bold())

                        Text("1. Create a Telegram Bot")
                            .font(.headline)
                        Text("Open @BotFather in Telegram and send /newbot. Follow the instructions to create your bot and get your Bot Token.")

                        Text("2. Create a Group")
                            .font(.headline)
                            .padding(.top)
                        Text("Create a new group in Telegram and add your bot to it. Make the bot an administrator.")

                        Text("3. Get Chat ID")
                            .font(.headline)
                            .padding(.top)
                        Text("Send a message in the group, then visit: https://api.telegram.org/botYOUR_TOKEN/getUpdates")
                        Text("Look for "chat":{"id":-123456789} - the number is your Chat ID (including the minus sign).")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
