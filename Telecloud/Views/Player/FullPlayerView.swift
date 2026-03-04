
import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.black, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.purple.opacity(0.5), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 320, height: 320)
                        .shadow(color: .purple.opacity(0.4), radius: 30, x: 0, y: 20)

                    Image(systemName: "music.note")
                        .font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 20)

                VStack(spacing: 8) {
                    Text(viewModel.currentItem?.file.filename ?? "Unknown Track")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(viewModel.currentItem?.file.metadata?.performer ?? "Unknown Artist")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 30)

                VStack(spacing: 8) {
                    Slider(value: Binding(get: { viewModel.currentTime }, set: { viewModel.seek(to: $0) }), in: 0...max(viewModel.duration, 1))
                        .tint(.white)

                    HStack {
                        Text(viewModel.formatTime(viewModel.currentTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(viewModel.formatTime(viewModel.duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 30)

                HStack(spacing: 40) {
                    Button(action: { viewModel.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.title2)
                            .foregroundColor(viewModel.isShuffled ? .green : .white.opacity(0.7))
                    }

                    Button(action: { viewModel.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }

                    Button(action: { viewModel.togglePlayPause() }) {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 80, height: 80)
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.black)
                        }
                    }

                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }

                    Button(action: { viewModel.toggleRepeat() }) {
                        Image(systemName: viewModel.repeatMode.icon)
                            .font(.title2)
                            .foregroundColor(viewModel.repeatMode != .none ? .green : .white.opacity(0.7))
                    }
                }

                HStack(spacing: 15) {
                    Image(systemName: "speaker.fill").font(.caption).foregroundColor(.white.opacity(0.7))
                    Slider(value: $viewModel.volume, in: 0...1).tint(.white)
                    Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 30)

                Spacer()

                HStack(spacing: 60) {
                    Button(action: {}) {
                        Image(systemName: "quote.bubble").font(.title2).foregroundColor(.white.opacity(0.7))
                    }
                    Button(action: {}) {
                        Image(systemName: "airplayaudio").font(.title2).foregroundColor(.white.opacity(0.7))
                    }
                    Button(action: {}) {
                        Image(systemName: "list.bullet").font(.title2).foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}
