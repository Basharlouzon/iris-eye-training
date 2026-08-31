import Foundation
import SwiftUI
import AppKit

/// Controls Apple Music through `osascript`. Apple Events trigger the standard
/// TCC prompt on first use; when denied the UI falls back gracefully.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    func nextTrack() {
        run(#"tell application "Music" to next track"#)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    func previousTrack() {
        run(#"tell application "Music" to previous track"#)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    func refresh() {
        guard musicRunning else {
            trackName = nil
            artistName = nil
            isPlaying = false
            progress = 0
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let script = """
            tell application "Music"
                set st to (player state as string)
                if (exists current track) then
                    set t to (name of current track)
                    set a to (artist of current track)
                    set d to (duration of current track)
                    set p to (player position)
                    return (t & "|" & a & "|" & st & "|" & (p as string) & "|" & (d as string))
                else
                    return ("||" & st & "|||")
                end if
            end tell
            """
            let output = Self.execute(script)
            let parsed = Self.parse(output)
            Task { @MainActor in self?.apply(parsed) }
        }
    }

    private func apply(_ result: (track: String?, artist: String?, playing: Bool, progress: Double)) {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            if let text = String(data: errData, encoding: .utf8),
               text.contains("-1743") || text.lowercased().contains("not authorized") {
                Task { @MainActor in MusicService.notifyDenied() }
            }
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func notifyDenied() {
        // Hop through the shared instance so the UI can react.
        Task { @MainActor in
            AppState.shared.music.denied = true
        }
    }

    private func run(_ source: String) {
        guard musicRunning else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = Self.execute(source)
        }
    }
}
