import AppKit
import SwiftUI

// Notch Simulator design: 160×21pt notch, full-width 100pt window, .screenSaver level
private let windowH: CGFloat = 100
private let notchW: CGFloat = 185  // matches MacBook Pro notch width (~160pt)
private let notchH: CGFloat = 30   // slightly taller than real notch (21pt) for content
private let notchRadius: CGFloat = 9  // real notch bottom curve radius

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

        panel.contentView = NSHostingView(rootView: NotchView().environmentObject(AppState.shared))
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

// Notch Simulator style: pure black, flat top flush with screen edge, only bottom corners rounded
struct NotchView: View {
    @EnvironmentObject private var appState: AppState

    private let hoverScale: CGFloat = 1.2

    private var isHovered: Bool { appState.notchHovered }
    private var currentW: CGFloat { isHovered ? notchW * hoverScale : notchW }
    private var currentH: CGFloat { isHovered ? notchH * hoverScale : notchH }
    private var currentR: CGFloat { isHovered ? notchRadius * hoverScale : notchRadius }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: currentR,
                    bottomTrailingRadius: currentR,
                    topTrailingRadius: 0
                )
                .fill(.black)

                HStack(spacing: 6) {
                    if let m = appState.activeModule { m.compactView() }
                }
                .padding(.horizontal, 12)
            }
            .frame(width: currentW, height: currentH)
            .position(x: geo.size.width / 2, y: currentH / 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
