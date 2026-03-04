
import Foundation
import AVFoundation
import Combine
import MediaPlayer

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentItem: MediaItem?
    @Published var queue: [MediaItem] = []
    @Published var currentIndex: Int = 0
    @Published var volume: Float = 1.0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .none

    enum RepeatMode: String, CaseIterable {
        case none = "None"
        case one = "One"
        case all = "All"

        var icon: String {
            switch self {
            case .none: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let fileSystemService = FileSystemService.shared

    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
        setupNowPlayingInfo()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func setupNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let item = currentItem {
            nowPlayingInfo[MPMediaItemPropertyTitle] = item.file.filename
            nowPlayingInfo[MPMediaItemPropertyArtist] = item.file.metadata?.performer ?? "Unknown Artist"

            if let artwork = item.artwork {
                let image = UIImage(data: artwork) ?? UIImage()
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Playback Control

    func play(item: MediaItem? = nil) {
        if let item = item {
            loadItem(item)
        }

        player?.play()
        isPlaying = true
        setupNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        setupNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player?.seek(to: cmTime)
        currentTime = time
    }

    // MARK: - Queue Management

    func setQueue(_ items: [MediaItem], startIndex: Int = 0) {
        queue = items
        currentIndex = startIndex
        if items.indices.contains(startIndex) {
            loadItem(items[startIndex])
        }
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }

        var nextIndex: Int

        if isShuffled {
            nextIndex = Int.random(in: 0..<queue.count)
        } else {
            nextIndex = currentIndex + 1
            if nextIndex >= queue.count {
                if repeatMode == .all {
                    nextIndex = 0
                } else {
                    return
                }
            }
        }

        currentIndex = nextIndex
        loadItem(queue[nextIndex])
        play()
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }

        var prevIndex = currentIndex - 1
        if prevIndex < 0 {
            if repeatMode == .all {
                prevIndex = queue.count - 1
            } else {
                return
            }
        }

        currentIndex = prevIndex
        loadItem(queue[prevIndex])
        play()
    }

    func toggleShuffle() {
        isShuffled.toggle()
    }

    func toggleRepeat() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .none
        }
    }

    // MARK: - Private Methods

    private func loadItem(_ item: MediaItem) {
        currentItem = item

        guard let url = item.localURL else { return }

        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe duration
        playerItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                self?.duration = CMTimeGetSeconds(self?.playerItem?.asset.duration ?? CMTime.zero)
                self?.setupNowPlayingInfo()
            }
        }

        // Add time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
            self?.setupNowPlayingInfo()
        }

        // Observe end of playback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        setupNowPlayingInfo()
    }

    @objc private func playerDidFinishPlaying() {
        if repeatMode == .one {
            seek(to: 0)
            play()
        } else {
            nextTrack()
        }
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}
