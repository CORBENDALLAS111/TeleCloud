
import SwiftUI

struct FileGridCell: View {
    let file: TelecloudFile
    let viewModel: FileManagerViewModel
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(iconColor.opacity(0.2))
                        .frame(height: 100)

                    Image(systemName: file.fileType.icon)
                        .font(.system(size: 40))
                        .foregroundColor(iconColor)

                    // Selection indicator
                    if viewModel.isSelectionMode {
                        Circle()
                            .fill(viewModel.selectedFiles.contains(file.id) ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: viewModel.selectedFiles.contains(file.id) ? "checkmark" : "")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                            )
                            .position(x: 85, y: 15)
                    }

                    // Play button for audio
                    if file.fileType == .audio {
                        Button(action: onPlay) {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                )
                        }
                        .position(x: 50, y: 70)
                    }
                }

                // Info
                VStack(spacing: 4) {
                    Text(file.filename)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    Text(viewModel.formatFileSize(file.fileSize))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconColor: Color {
        switch file.fileType {
        case .audio: return .pink
        case .video: return .purple
        case .document: return .blue
        case .image: return .green
        case .folder: return .orange
        }
    }
}

struct FolderGridCell: View {
    let folder: TelecloudFolder
    let viewModel: FileManagerViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.2))
                        .frame(height: 100)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                }

                VStack(spacing: 4) {
                    Text(folder.name)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    Text("\(itemCount) items")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var itemCount: Int {
        viewModel.files.filter { $0.folderId == folder.id }.count +
        viewModel.folders.filter { $0.parentId == folder.id }.count
    }
}
