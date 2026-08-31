import SwiftUI

enum DashboardPlacement: Equatable {
    case notch(topInset: CGFloat)
    case statusItem

    var topInset: CGFloat {
        switch self {
        case let .notch(topInset): topInset
        case .statusItem: 0
        }
    }
}

struct StatusDashboardView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: PanelModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

            IrisDashboardView(
                state: state,
                model: model,
                topInset: DashboardPlacement.statusItem.topInset
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.50), radius: 32, y: 14)
    }
}
