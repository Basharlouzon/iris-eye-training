import Foundation
import SwiftUI
import AppKit

/// Controls Apple Music. Reads track info and drives playback via AppleScript.
///
/// Uses NSAppleScript executed on the main thread — this works both in normal
/// (ad-hoc / Developer ID) builds and inside the App Sandbox for App Store
/// builds (paired with the com.apple.security.scripting-targets entitlement).
/// First execution triggers the standard macOS "Iris wants to control Music"
/// consent; denial is surfaced through `denied`.
@MainActor
final class MusicService: ObservableObject {
    @Published var trackName: String?
    @Published var artistName: String?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var denied = false

    private var pollTimer: Timer?

    private var musicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        refresh()
        let t = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 0.5
        pollTimer = t
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func togglePlayPause() {
        run(#"tell application "Music" to playpause"#)
        refresh()
    }

    func nextTrack() {
        run(#"tell application "Music" to next track"#)
        refresh()
    }

    func previousTrack() {
        run(#"tell application "Music" to previous track"#)
        refresh()
    }

    func refresh() {
        guard musicRunning else {
            trackName = nil
            artistName = nil
            isPlaying = false
            progress = 0
            return
        }
        // Note: variable names must avoid Music dictionary terminology
        // (e.g. `st` is rejected) and radio streams have no duration/position,
        // so those are read defensively.
        let output = Self.execute("""
        tell application "Music"
            set playerState to (player state as string)
            set trackTitle to ""
            set trackArtist to ""
            set trackPos to ""
            set trackDur to ""
            if (exists current track) then
                set trackTitle to (name of current track)
                set trackArtist to (artist of current track)
                try
                    set trackPos to ((player position) as string)
                end try
                try
                    set trackDur to ((duration of current track) as string)
                end try
            end if
            return (trackTitle & "|" & trackArtist & "|" & playerState & "|" & trackPos & "|" & trackDur)
        end tell
        """)
        apply(Self.parse(output))
    }

    private func apply(_ result: (track: String?, artist: String?, playing: Bool, progress: Double)) {
        // A successful read means Automation access is working again.
        if result.track != nil || !result.playing {
            denied = false
        }
        trackName = result.track
        artistName = result.artist
        isPlaying = result.playing
        progress = result.progress.isFinite ? min(max(result.progress, 0), 1) : 0
    }

    nonisolated private static func parse(_ output: String?) -> (String?, String?, Bool, Double) {
        guard let output, !output.isEmpty else { return (nil, nil, false, 0) }
        let parts = output.components(separatedBy: "|")
        let track = parts.count > 0 && !parts[0].isEmpty ? parts[0] : nil
        let artist = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        let state = parts.count > 2 ? parts[2] : ""
        let pos = parts.count > 3 ? Double(parts[3]) ?? 0 : 0
        let dur = parts.count > 4 ? Double(parts[4]) ?? 0 : 0
        let progress = dur > 0 ? pos / dur : 0
        return (track, artist, state == "playing", progress)
    }

    @discardableResult
    private static func execute(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 {
                Task { @MainActor in MusicService.notifyDenied() }
            }
            return nil
        }
        return descriptor.stringValue
    }

    nonisolated private static func notifyDenied() {
        Task { @MainActor in
            AppState.shared.music.denied = true
        }
    }

    private func run(_ source: String) {
        guard musicRunning else { return }
        _ = Self.execute(source)
    }
}
