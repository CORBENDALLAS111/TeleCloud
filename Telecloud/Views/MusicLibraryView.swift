
import SwiftUI

struct MusicLibraryView: View {
    @StateObject private var viewModel = FileManagerViewModel()
    @StateObject private var playerViewModel = PlayerViewModel()

    var audioFiles: [TelecloudFile] {
        viewModel.fileSystemService.index.files.filter { $0.fileType == .audio }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                if !audioFiles.isEmpty {
                    Section(header: Text("All Songs").foregroundColor(.gray)) {
                        ForEach(audioFiles) { file in
                            MusicRow(file: file, viewModel: viewModel) {
                                playerViewModel.play(file: file)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No music found")
                                    .foregroundColor(.gray)
                                Text("Add audio files to your Telegram group")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 60)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                viewModel.sync()
            }

            if playerViewModel.currentItem != nil {
                VStack {
                    Spacer()
                    MiniPlayerView(viewModel: playerViewModel)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}

struct MusicRow: View {
    let file: TelecloudFile
    let viewModel: FileManagerViewModel
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.pink.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.metadata?.title ?? file.filename)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Text(file.metadata?.performer ?? "Unknown Artist")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
