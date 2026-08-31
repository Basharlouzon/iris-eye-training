import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: AppState
    let topInset: CGFloat

    @AppStorage(SettingsKeys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKeys.routinePreset) private var selectedRoutineID = RoutinePreset.balanced.id
    @State private var step: OnboardingStep = .promise

    private var selectedRoutine: RoutinePreset {
        RoutinePreset.all.first { $0.id == selectedRoutineID } ?? .balanced
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset + 8)
            HStack {
                Text("Iris")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(step.rawValue + 1) / \(OnboardingStep.allCases.count)")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case .promise: promise
                case .routine: routine
                case .privacy: privacy
                }
                Spacer(minLength: 8)
                IrisActionButton(
                    title: actionTitle,
                    style: step == .privacy ? .restorative : .accent,
                    action: advance
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private var actionTitle: String {
        switch step {
        case .promise: "Set up Iris"
        case .routine: "Use \(selectedRoutine.title.lowercased()) routine"
        case .privacy: "Start free"
        }
    }

    private var promise: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.accent, lineWidth: 2)
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(Theme.restorative)
                    .frame(width: 34, height: 34)
            }
            Text("Your eyes deserve a better workday.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Iris notices long stretches, guides restorative breaks, and builds a calmer daily rhythm.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            IrisSurfaceCard(
                eyebrow: "Designed for real work",
                title: "Gentle, useful, private",
                detail: "No guilt loops. No attention-grabbing dashboard. Just the next useful action.",
                tone: .accent
            )
        }
    }

    private var routine: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build a realistic rhythm.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text("Start small. Iris adapts timing from your on-device activity and comfort signals.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(RoutinePreset.all) { preset in
                routineOption(preset)
            }
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Helpful without being invasive.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your routine works fully on-device. Extra context is always optional and reversible.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            IrisSurfaceCard(
                eyebrow: "On-device • Included",
                title: "Activity and comfort signals",
                detail: "Used locally to adjust break timing. Nothing leaves your Mac.",
                tone: .restorative
            )
            IrisSurfaceCard(
                eyebrow: "Optional • Off",
                title: "Calendar + Focus mode",
                detail: "Avoid interruptions during meetings and protect deep-work windows."
            )
        }
    }

    private func routineOption(_ preset: RoutinePreset) -> some View {
        let selected = preset.id == selectedRoutineID
        return Button {
            selectedRoutineID = preset.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(preset.focusMinutes) min focus • \(preset.restSeconds) sec reset")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                Text(selected ? "SELECTED" : "CHOOSE")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(selected ? Theme.surfaceStrong : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        if let next = step.next {
            step = next
            return
        }
        UserDefaults.standard.set(Double(selectedRoutine.focusMinutes), forKey: SettingsKeys.breakInterval)
        state.breakIntervalChanged(to: Double(selectedRoutine.focusMinutes))
        hasOnboarded = true
    }
}
