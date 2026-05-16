import SwiftUI

/// Reusable progress bar for elapsed time, battery, etc.
struct ProgressBar: View {
    let progress: Double // 0...1
    let color: Color
    let height: CGFloat
    let showGlow: Bool

    init(
        progress: Double,
        color: Color = .white,
        height: CGFloat = 4,
        showGlow: Bool = false
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.height = height
        self.showGlow = showGlow
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.2))
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: height)
                    .shadow(
                        color: showGlow ? color.opacity(0.5) : .clear,
                        radius: showGlow ? 4 : 0
                    )
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.5), value: progress)
    }
}

// MARK: - Equalizer Bars

/// Animated equalizer bars for Now Playing compact view
struct EqualizerBars: View {
    private let lowHeights: [CGFloat] = [4, 6, 5, 7]
    private let highHeights: [CGFloat] = [8, 12, 9, 11]

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.7))
                    .frame(width: 1.5, height: animating ? highHeights[i] : lowHeights[i])
                    .animation(
                        .easeInOut(duration: 0.4)
                        .delay(Double(i) * 0.15)
                        .repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }

    @State private var animating = false
}
