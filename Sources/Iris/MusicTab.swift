import SwiftUI

/// Music player tab (reference 2, left side of the notch bar).
struct MusicTab: View {
    @ObservedObject var state: AppState
    @ObservedObject var music: MusicService

    init(state: AppState) {
        self.state = state
        self.music = state.music
    }

    var body: some View {
        VStack(spacing: 12) {
            if music.denied {
                deniedView
            } else if music.trackName == nil {
                emptyView
            } else {
                playerView
            }
        }
        .padding(.top, 6)
    }

    private var playerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.gradientTop, Theme.gradientBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(music.trackName ?? "—")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(music.artistName ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                    ProgressView(value: music.progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.accent)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 26) {
                controlButton("backward.fill", size: 18) { music.previousTrack() }
                controlButton(music.isPlaying ? "pause.fill" : "play.fill", size: 22) { music.togglePlayPause() }
                    .background(Circle().fill(Color.white).frame(width: 44, height: 44))
                controlButton("forward.fill", size: 18) { music.nextTrack() }
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.secondary)
            Text("Nothing playing")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Open the Music app and start a song — control it right from your notch.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .cardStyle()
    }

    private var deniedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            Text("Music access not granted")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Allow Iris to control Music in System Settings → Privacy & Security → Automation.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .cardStyle()
    }

    private func controlButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
