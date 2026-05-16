import AppKit
import SwiftUI

private let windowH: CGFloat = 100
private let notchW: CGFloat = 185   // matches MacBook Pro notch width
private let notchCapH: CGFloat = 22 // physical notch height (hardware covers this)
private let contentH: CGFloat = 16  // visible strip below physical notch
private let notchH: CGFloat = notchCapH + contentH  // total shape height = 38pt
private let notchRadius: CGFloat = 9

@MainActor
final class IslandWindow: NSObject, NSWindowDelegate {
    private var islandPanel: NSPanel?
    private var expandedPanel: NSPanel?
    private var isExpanded = false
    private var mouseMonitor: Any?

    func show() {
        guard let screen = NSScreen.main else { return }

        // Panel covers only the notch region — ignores mouse events (pass-through)
        let panelW = notchW * 2.0 + 80
        let rect = NSRect(x: screen.frame.midX - panelW / 2, y: screen.frame.maxY - windowH, width: panelW, height: windowH)

        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // Pass all mouse events through — menu bar stays fully clickable
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: NotchView().environmentObject(AppState.shared))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 0
        hostingView.layer?.masksToBounds = false
        panel.contentView = hostingView
        panel.orderFront(nil)
        self.islandPanel = panel
        AppState.shared.islandWindow = self

        // Global mouse monitor drives hover state without blocking events
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
    }

    private func updateHover() {
        guard let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
        // Notch hit region in screen coords (AppKit bottom-up: maxY = screen top)
        let hoverW = notchW * 1.5
        let hoverH = notchH * 1.5
        let inZone = abs(mouse.x - screen.frame.midX) < hoverW / 2
                  && mouse.y > screen.frame.maxY - hoverH
        AppState.shared.notchHovered = inZone
    }

    func toggleExpanded() { isExpanded ? collapse() : expand() }

    private func expand() {
        guard let screen = NSScreen.main else { return }
        expandedPanel?.close()
        let r = NSRect(x: screen.frame.midX - 170, y: screen.frame.maxY - notchH - 288, width: 340, height: 280)
        let p = NSPanel(contentRect: r, styleMask: [.borderless, .nonactivatingPanel, .titled], backing: .buffered, defer: false)
        p.level = NSWindow.Level.floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.delegate = self
        p.contentView = NSHostingView(rootView: ExpandedView().environmentObject(AppState.shared))
        p.orderFront(nil)
        p.makeKey()
        self.expandedPanel = p
        isExpanded = true
        AppState.shared.isExpanded = true
    }

    private func collapse() {
        expandedPanel?.close()
        expandedPanel = nil
        isExpanded = false
        AppState.shared.isExpanded = false
    }

    func setExpanded(_ v: Bool) { if v { expand() } else { collapse() } }
    func dismissExpanded() { if isExpanded { collapse() } }
    func hide() { islandPanel?.orderOut(nil); expandedPanel?.orderOut(nil) }
    func terminate() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        islandPanel?.close(); expandedPanel?.close()
        islandPanel = nil; expandedPanel = nil
    }
    func windowDidResignKey(_ n: Notification) { if (n.object as? NSWindow) == expandedPanel { dismissExpanded() } }
}

// Morph transition phases
private enum MorphPhase: Equatable { case idle, widening, swapping, narrowing }

// Notch Simulator style: pure black, flat top flush with screen edge, only bottom corners rounded
struct NotchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @State private var morphPhase: MorphPhase = .idle
    @State private var displayedModuleID: String? = nil

    private let hoverScale: CGFloat = 1.2
    private let morphScale: CGFloat = 1.12

    private var hasContent: Bool { displayedModule != nil }

    private var currentW: CGFloat {
        let base: CGFloat
        switch morphPhase {
        case .widening, .swapping: base = notchW * morphScale
        default: base = isHovered ? notchW * hoverScale : notchW
        }
        return base
    }
    // Height scales proportionally on hover (same ratio as width)
    private var currentH: CGFloat { isHovered && morphPhase == .idle ? notchH * hoverScale : notchH }
    private var currentR: CGFloat { isHovered && morphPhase == .idle ? notchRadius * hoverScale : notchRadius }
    // Content height = visible area below physical notch cap, scaled same as overall
    private var currentContentH: CGFloat { isHovered && morphPhase == .idle ? contentH * hoverScale : contentH }
    private var contentOpacity: Double { morphPhase == .swapping ? 0.0 : 1.0 }

    private var displayedModule: IslandModule? {
        guard let id = displayedModuleID else { return appState.activeCarouselModule }
        return appState.carouselModules.first { $0.id == id } ?? appState.activeCarouselModule
    }

    var body: some View {
        GeometryReader { geo in
            // ZStack aligned to bottom so content anchors below the cap (physical notch area)
            ZStack(alignment: .bottom) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: currentR,
                    bottomTrailingRadius: currentR,
                    topTrailingRadius: 0
                )
                .fill(.black)
                .frame(width: currentW, height: currentH)

                // Content in the visible strip below the physical notch cap
                HStack(spacing: 6) {
                    if let m = displayedModule { m.compactView() }
                }
                .frame(height: currentContentH)
                .padding(.horizontal, 12)
                .opacity(contentOpacity)
                .animation(.easeInOut(duration: 0.06), value: contentOpacity)
            }
            .frame(width: currentW, height: currentH)
            // y: currentH / 2 keeps top edge flush with screen top (SwiftUI top-down coords)
            .position(x: geo.size.width / 2, y: currentH / 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: currentW)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentH)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
            .onChange(of: appState.carouselIndex, initial: false) {
                triggerMorph()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            displayedModuleID = appState.activeCarouselModule?.id
        }
    }

    private func triggerMorph() {
        guard morphPhase == .idle else { return }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) { morphPhase = .widening }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            morphPhase = .swapping
            displayedModuleID = appState.activeCarouselModule?.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) { morphPhase = .narrowing }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            morphPhase = .idle
        }
    }
}
