import SwiftUI

/// Balanced (Style B) compact layout used by all modules.
/// [ left ] [ separator ] [ label (9px, dim) / value (11px, white) ] [ right ]
struct NotchActivityView: View {
    var left: AnyView? = nil
    var label: String = ""
    var value: String
    var rightBar: BarConfig? = nil
    var rightDot: DotConfig? = nil

    struct BarConfig {
        var fraction: Double
        var color: Color
    }

    struct DotConfig {
        var color: Color
        var pulse: Bool
    }

    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 0) {
            if let left {
                left
                    .frame(width: 18)
                Divider()
                    .frame(width: 1, height: 16)
                    .background(.white.opacity(0.1))
                    .padding(.horizontal, 5)
            }

            VStack(alignment: .leading, spacing: 1) {
                if !label.isEmpty {
                    Text(label.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(0.6)
                }
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if let bar = rightBar {
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.12))
                        .frame(width: 36, height: 3)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(bar.color)
                                .frame(width: max(0, 36 * bar.fraction), height: 3)
                        }
                }
            }

            if let dot = rightDot {
                Circle()
                    .fill(dot.color)
                    .frame(width: 5, height: 5)
                    .opacity(dot.pulse ? (dotPulse ? 1.0 : 0.3) : 1.0)
                    .onAppear {
                        if dot.pulse {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                dotPulse = true
                            }
                        }
                    }
            }
        }
    }
}
