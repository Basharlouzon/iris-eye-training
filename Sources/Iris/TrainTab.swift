import SwiftUI

struct TrainTab: View {
    @ObservedObject var state: AppState
    @ObservedObject private var session: ExerciseSession
    @State private var completedIDs: Set<String> = []

    private let routine = TrainingRoutine.approved

    init(state: AppState) {
        self.state = state
        session = state.exercises
    }

    private var exercises: [Exercise] {
        routine.stepIDs.compactMap { id in
            Exercise.catalog.first { $0.id == id }
        }
    }

    private var currentRoutineIndex: Int {
        exercises.firstIndex { $0.id == session.selectedID } ?? 0
    }

    /// Focus queue for the training card: the routine when the selected drill
    /// belongs to it, otherwise the whole library starting at the selection.
    private var focusQueue: [Exercise] {
        exercises.contains { $0.id == session.selectedID } ? exercises : Exercise.catalog
    }

    private var focusIndex: Int {
        focusQueue.firstIndex { $0.id == session.selectedID } ?? 0
    }

    private func startFocusMode() {
        session.duration = routine.stepDurationSeconds
        TheaterController.shared.present(steps: focusQueue, index: focusIndex)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today’s 4-minute reset")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Four calm movements. One minute each.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                IrisStatusChip(label: "4 steps", tone: .accent)
            }

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                IrisExerciseRow(
                    number: index + 1,
                    title: exercise.name,
                    detail: stepDetail(for: exercise),
                    state: rowState(for: exercise)
                ) {
                    select(exercise)
                }
            }

            trainingCard

            librarySection
        }
        .onAppear {
            if !routine.stepIDs.contains(session.selectedID), let first = exercises.first {
                select(first)
            }
        }
        .onChange(of: session.justCompleted) { complete in
            if complete {
                completedIDs.insert(session.selectedID)
            }
        }
    }

    private func rowState(for exercise: Exercise) -> IrisExerciseRow.State {
        if completedIDs.contains(exercise.id) { return .complete }
        if exercise.id == session.selectedID { return .current }
        return .available
    }

    private func stepDetail(for exercise: Exercise) -> String {
        switch exercise.id {
        case "fig8": "Slow tracking • 60 sec"
        case "infinity": "Side-to-side flow • 60 sec"
        case "zigzag": "Controlled scanning • 60 sec"
        case "diagonals": "Corner focus • 60 sec"
        default: exercise.hint
        }
    }

    // MARK: Exercise library (parity with the web app's library design)

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EXERCISE LIBRARY")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.tertiary)
                Spacer()
                IrisStatusChip(label: "\(Exercise.catalog.count) drills", tone: .neutral)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(Exercise.catalog) { exercise in
                    libraryCard(exercise)
                }
            }
        }
    }

    private func libraryCard(_ exercise: Exercise) -> some View {
        let isSelected = exercise.id == session.selectedID
        return Button {
            select(exercise)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ExercisePreviewCanvas(kind: exercise.kind, loopSeconds: 8)
                    .frame(height: 74)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        launchButton(exercise)
                            .padding(6)
                    }
                HStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.text)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(6)
            .background(isSelected ? Theme.surfaceStrong : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.55) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(session.running)
    }

    /// Launches Focus Mode with the whole library queued, starting here,
    /// so next/prev can browse every drill.
    private func launchButton(_ exercise: Exercise) -> some View {
        Button {
            session.duration = routine.stepDurationSeconds
            if let idx = Exercise.catalog.firstIndex(where: { $0.id == exercise.id }) {
                TheaterController.shared.present(steps: Exercise.catalog, index: idx)
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.surfaceStrong, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(session.running)
        .help("Focus mode — play this drill")
    }

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.running ? "FOLLOW THE ORANGE DOT" : "CURRENT STEP")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.2)
                        .foregroundStyle(Theme.accent)
                    Text(session.selected.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                if session.running {
                    IrisStatusChip(label: "Live", tone: .accent)
                }
            }

            TrainPreview(session: session)
                .frame(height: 96)

            HStack(spacing: 12) {
                Text(session.selected.hint)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if session.running {
                    IrisActionButton(title: "Stop", style: .quiet) {
                        session.stop()
                    }
                } else {
                    IrisActionButton(title: "Focus mode", style: .accent) {
                        startFocusMode()
                    }
                    IrisActionButton(title: "Play here", style: .quiet) {
                        session.duration = routine.stepDurationSeconds
                        session.start()
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func select(_ exercise: Exercise) {
        guard !session.running else { return }
        session.justCompleted = false
        session.duration = routine.stepDurationSeconds
        session.select(exercise)
    }
}

private struct TrainPreview: View {
    @ObservedObject var session: ExerciseSession

    var body: some View {
        ExercisePreviewCanvas(kind: session.selected.kind,
                              startedAt: session.startedAt,
                              elapsedBase: session.accumulated,
                              loopSeconds: session.loopSeconds,
                              reversed: session.reversed,
                              paused: !session.running,
                              plain: true)
            .frame(height: 96)
    }
}
