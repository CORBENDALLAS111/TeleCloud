
import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                FileManagerView()
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "folder.fill")
                Text("Files")
            }
            .tag(0)

            NavigationView {
                MusicLibraryView()
                    .navigationTitle("Music")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "music.note")
                Text("Music")
            }
            .tag(1)

            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
        .accentColor(.purple)
    }
}
