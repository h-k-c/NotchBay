import SwiftUI

/// Reusable status indicator — colored dot with optional pulse animation
struct StatusIndicator: View {
    enum IndicatorState {
        case idle
        case active(color: Color)
        case pulsing(color: Color)
        case breathing(color: Color)

        var color: Color {
            switch self {
            case .idle: return .gray
            case .active(let c), .pulsing(let c), .breathing(let c): return c
            }
        }
    }

    let state: IndicatorState
    let size: CGFloat

    init(state: IndicatorState = .idle, size: CGFloat = 6) {
        self.state = state
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: size, height: size)
            .opacity(opacity)
            .scaleEffect(scale)
            .animation(animation, value: shouldAnimate)
    }

    @State private var shouldAnimate: Bool = false

    private var opacity: Double {
        switch state {
        case .idle: return 0.4
        case .active: return 1.0
        case .pulsing: return shouldAnimate ? 0.3 : 1.0
        case .breathing: return shouldAnimate ? 0.6 : 1.0
        }
    }

    private var scale: CGFloat {
        switch state {
        case .breathing: return shouldAnimate ? 1.3 : 1.0
        default: return 1.0
        }
    }

    private var animation: Animation? {
        switch state {
        case .idle, .active: return nil
        case .pulsing:
            return .easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true)
        case .breathing:
            return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        }
    }

    func onAppear() -> some View {
        self.onAppear { shouldAnimate = true }
            .onDisappear { shouldAnimate = false }
    }
}

// MARK: - Preview Helper

extension StatusIndicator.IndicatorState {
    static var thinking: StatusIndicator.IndicatorState { .pulsing(color: .statusPurple) }
    static var executing: StatusIndicator.IndicatorState { .active(color: .statusGreen) }
    static var waitingApproval: StatusIndicator.IndicatorState { .breathing(color: .statusOrange) }
    static var error: StatusIndicator.IndicatorState { .active(color: .statusRed) }
}
