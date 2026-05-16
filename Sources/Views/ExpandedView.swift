import SwiftUI

/// The expanded dropdown panel that shows detailed info for the active module
struct ExpandedView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: String = ""
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: 0) {
                // Active module expanded content
                if let module = appState.activeModule {
                    module.expandedView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id(module.id)
                }

                // Quick module switcher tabs
                moduleTabs
            }
        }
        .frame(width: Constants.expandedWidth)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            NSCursor.arrow.push()
        }
    }

    // MARK: - Subviews

    private var moduleTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.modules) { module in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.sceneDetector.switchTo(moduleID: module.id)
                            appState.activeModuleID = module.id
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: module.icon)
                                .font(.system(size: 10))
                            Text(module.name)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(
                            module.id == appState.activeModuleID
                                ? .white
                                : .white.opacity(0.5)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    module.id == appState.activeModuleID
                                        ? .white.opacity(0.15)
                                        : .white.opacity(0.05)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}
