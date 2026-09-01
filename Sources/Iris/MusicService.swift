import Foundation
import SwiftUI
import AppKit

/// Controls Apple Music. Reads track info and drives playback via AppleScript
/// executed on a dedicated serial background queue with per-script timeouts, so
/// a hung Music app or a stalled consent dialog can never freeze the UI.
///
/// Works inside the App Sandbox (NSAppleScript + the automation entitlement).
/// First execution triggers the standard macOS "Iris wants to control Music"
/// consent; denial is surfaced through `denied` and only cleared by a
/// subsequent successful read.
@MainActor
final class MusicService: ObservableObject {
    @Published var trackName: String?
    @Published var artistName: String?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var denied = false

    private var pollTimer: Timer?
    private let scriptQueue = DispatchQueue(label: "app.iris.applescript", qos: .utility)

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
    }

    func nextTrack() {
        run(#"tell application "Music" to next track"#)
    }

    func previousTrack() {
        run(#"tell application "Music" to previous track"#)
    }

    func refresh() {
        guard musicRunning else {
            trackName = nil
            artistName = nil
            isPlaying = false
            progress = 0
            return
        }
        scriptQueue.async { [weak self] in
            // Note: variable names must avoid Music dictionary terminology
            // (e.g. `st` is rejected) and radio streams have no duration or
            // player position, so those are read defensively.
            let output = Self.execute("""
            with timeout of 3 seconds
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
            end timeout
            """)
            let parsed = Self.parse(output)
            Task { @MainActor in self?.apply(parsed, readSucceeded: output != nil) }
        }
    }

    private func apply(_ result: (track: String?, artist: String?, playing: Bool, progress: Double),
                       readSucceeded: Bool) {
        // Only a successful AppleScript read proves Automation access works;
        // a denial or a timeout must never clear the flag by itself.
        if readSucceeded {
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

    nonisolated private static func execute(_ source: String) -> String? {
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
        scriptQueue.async { [weak self] in
            _ = Self.execute(source)
            Task { @MainActor in self?.refresh() }
        }
    }
}
