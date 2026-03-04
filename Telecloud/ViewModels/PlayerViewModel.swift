
import Foundation
import Combine

class PlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentItem: MediaItem?
    @Published var queue: [MediaItem] = []
    @Published var currentIndex: Int = 0
    @Published var isShuffled: Bool = false
    @Published var repeatMode: AudioPlayerService.RepeatMode = .none
    @Published var volume: Float = 1.0
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0

    private let playerService = AudioPlayerService.shared
    private let fileSystemService = FileSystemService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        playerService.$isPlaying
            .assign(to: &$isPlaying)

        playerService.$currentTime
            .assign(to: &$currentTime)

        playerService.$duration
            .assign(to: &$duration)

        playerService.$currentItem
            .assign(to: &$currentItem)

        playerService.$queue
            .assign(to: &$queue)

        playerService.$currentIndex
            .assign(to: &$currentIndex)

        playerService.$isShuffled
            .assign(to: &$isShuffled)

        playerService.$repeatMode
            .assign(to: &$repeatMode)

        playerService.$volume
            .assign(to: &$volume)
    }

    func play(file: TelecloudFile) {
        isDownloading = true
        downloadProgress = 0

        fileSystemService.downloadFile(file)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isDownloading = false
                    if case .failure(let error) = completion {
                        print("Download error: \(error)")
                    }
                },
                receiveValue: { [weak self] url in
                    guard let self = self else { return }
                    let item = MediaItem(
                        id: file.id,
                        file: file,
                        downloadURL: nil,
                        localURL: url,
                        artwork: nil
                    )
                    self.playerService.play(item: item)
                }
            )
            .store(in: &cancellables)
    }

    func playQueue(files: [TelecloudFile], startIndex: Int) {
        let items = files.map { file in
            MediaItem(
                id: file.id,
                file: file,
                downloadURL: nil,
                localURL: fileSystemService.getLocalFileURL(for: file),
                artwork: nil
            )
        }

        // Download first item if needed
        if items.indices.contains(startIndex) {
            let startItem = items[startIndex]
            if startItem.localURL == nil {
                play(file: files[startIndex])
            } else {
                playerService.setQueue(items, startIndex: startIndex)
                playerService.play()
            }
        }
    }

    func togglePlayPause() {
        playerService.togglePlayPause()
    }

    func seek(to time: Double) {
        playerService.seek(to: time)
    }

    func nextTrack() {
        playerService.nextTrack()
    }

    func previousTrack() {
        playerService.previousTrack()
    }

    func toggleShuffle() {
        playerService.toggleShuffle()
    }

    func toggleRepeat() {
        playerService.toggleRepeat()
    }

    func setVolume(_ volume: Float) {
        playerService.volume = volume
    }

    func formatTime(_ time: Double) -> String {
        guard !time.isNaN, time.isFinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func progressPercentage() -> Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}
