import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var offset: CGFloat = 0
    @State private var needsScroll = false
    @State private var textWidth: CGFloat = 0

    init(text: String, font: Font = .system(size: 11), color: Color = .white) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeo in
                        Color.clear.preference(
                            key: TextWidthKey.self,
                            value: textGeo.size.width
                        )
                    }
                )
                .onPreferenceChange(TextWidthKey.self) { width in
                    textWidth = width
                    needsScroll = width > geo.size.width
                }
                .offset(x: needsScroll ? offset : 0)
                .mask(fadeMask)
                .onAppear {
                    guard needsScroll else { return }
                    startAnimation(containerWidth: geo.size.width)
                }
                .onDisappear {
                    offset = 0
                }
        }
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.white)
            if needsScroll {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
            }
        }
    }

    private func startAnimation(containerWidth: CGFloat) {
        let totalDistance = textWidth - containerWidth + 40
        let duration = max(totalDistance / 20, 2.0) // 20pt/s, min 2s

        withAnimation(.linear(duration: duration).delay(1.5)) {
            offset = -totalDistance
        }

        // Schedule loop via Timer (cleaner than nested asyncAfter)
        Timer.scheduledTimer(withTimeInterval: duration + 4.0, repeats: false) { _ in
            withAnimation(.none) { offset = 0 }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                startAnimation(containerWidth: containerWidth)
            }
        }
    }
}

private struct TextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
