import AppKit
import SwiftUI

private let windowH: CGFloat = 100
private let notchW: CGFloat = 185   // matches MacBook Pro notch width
private let notchCapH: CGFloat = 22 // physical notch height (hardware covers this)
private let contentH: CGFloat = 24  // visible strip below physical notch (needs ~22pt for 8+11pt text)
private let notchH: CGFloat = notchCapH + contentH  // total shape height = 46pt
private let notchRadius: CGFloat = 9

@MainActor
final class IslandWindow: NSObject, NSWindowDelegate {
    private var islandPanel: NSPanel?
    private var expandedPanel: NSPanel?
    private var isExpanded = false
    private var mouseMonitor: Any?

    func show() {
        guard let screen = NSScreen.main else { return }

        // Panel extends 10pt above screen so macOS corner-softening artifacts are off-screen
        let panelW = notchW * 2.0 + 80
        let overbleed: CGFloat = 10
        let rect = NSRect(x: screen.frame.midX - panelW / 2, y: screen.frame.maxY - windowH + overbleed, width: panelW, height: windowH + overbleed)

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

    // User-adjustable via Settings > 外观 > 刘海形状
    @AppStorage("notch.width")         private var storedW:       Double = 185
    @AppStorage("notch.capHeight")     private var storedCapH:    Double = 22
    @AppStorage("notch.contentHeight") private var storedContent: Double = 24
    @AppStorage("notch.topRadius")     private var storedTopR:    Double = 8
    @AppStorage("notch.bottomRadius")  private var storedBottomR: Double = 9

    private var baseW:       CGFloat { CGFloat(storedW) }
    private var baseH:       CGFloat { CGFloat(storedCapH + storedContent) }
    private var baseTopR:    CGFloat { min(CGFloat(storedTopR), 50) }
    private var baseBottomR: CGFloat { CGFloat(storedBottomR) }
    private var baseContentH: CGFloat { CGFloat(storedContent) }

    private let hoverScale: CGFloat = 1.2
    private let morphScale: CGFloat = 1.12

    private var hasContent: Bool { displayedModule != nil }

    private var currentW: CGFloat {
        switch morphPhase {
        case .widening, .swapping: return baseW * morphScale
        default: return isHovered ? baseW * hoverScale : baseW
        }
    }
    private var currentH: CGFloat { isHovered && morphPhase == .idle ? baseH * hoverScale : baseH }
    private var currentTopR: CGFloat { isHovered && morphPhase == .idle ? baseTopR * hoverScale : baseTopR }
    private var currentBottomR: CGFloat { isHovered && morphPhase == .idle ? baseBottomR * hoverScale : baseBottomR }
    private var currentContentH: CGFloat { isHovered && morphPhase == .idle ? baseContentH * hoverScale : baseContentH }
    private var contentOpacity: Double { morphPhase == .swapping ? 0.0 : 1.0 }

    private var displayedModule: IslandModule? {
        guard let id = displayedModuleID else { return appState.activeCarouselModule }
        return appState.carouselModules.first { $0.id == id } ?? appState.activeCarouselModule
    }

    var body: some View {
        GeometryReader { geo in
            // Custom Path guarantees pixel-perfect flat top corners (no anti-aliased rounding)
            ZStack(alignment: .bottom) {
                NotchShape(topRadius: currentTopR, bottomRadius: currentBottomR)
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
            // Panel is 10pt above screen; +10 shifts shape down so top aligns with actual screen top
            .position(x: geo.size.width / 2, y: currentH / 2 + 10)
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

/// Notch shape with independently controllable top and bottom corner radii.
/// Uses explicit Path so all four corners are pixel-perfect — no SwiftUI anti-aliased rounding.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = min(topRadius, rect.height / 2, rect.width / 2)
        let br = min(bottomRadius, rect.height / 2, rect.width / 2)
        // Outer tip rounding radius — small convex arc at the top-left/right outer corners
        // so the cusp (180° direction reversal) becomes a smooth rounded tip
        let tipR: CGFloat = tr > 0 ? max(tr * 0.3, 2) : 0
        var p = Path()

        // Top edge: straight section between the two rounded outer tips
        p.move(to: CGPoint(x: rect.minX - tr + tipR, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX + tr - tipR, y: rect.minY))

        // Top-right outer tip: small convex arc rounding the outer corner
        // center is slightly inside the tip; arc goes from top-edge tangent → downward tangent
        p.addArc(center: CGPoint(x: rect.maxX + tr - tipR, y: rect.minY + tipR),
                 radius: tipR,
                 startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)

        // Top-right concave curve: from outer tip → body right side
        // Bézier with exact tangent match for G1 continuity
        let k: CGFloat = 0.5523
        let cLen = tr - tipR          // effective concave span
        if cLen > 0 {
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                       control1: CGPoint(x: rect.maxX + tipR + cLen * (1 - k), y: rect.minY + tipR),
                       control2: CGPoint(x: rect.maxX, y: rect.minY + tipR + cLen * (1 - k)))
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tr))
        }

        // Right side down
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

        // Bottom-right: convex arc (verified working: clockwise: false = CW visual in y-down)
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                     radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }

        // Bottom edge
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))

        // Bottom-left: convex arc
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.minX + br, y: rect.maxY - br),
                     radius: br, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }

        // Left side up
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))

        // Top-left concave curve: from body left side → outer tip
        if cLen > 0 {
            p.addCurve(to: CGPoint(x: rect.minX - tr + tipR, y: rect.minY + tipR),
                       control1: CGPoint(x: rect.minX, y: rect.minY + tipR + cLen * (1 - k)),
                       control2: CGPoint(x: rect.minX - tipR - cLen * (1 - k), y: rect.minY + tipR))
        } else {
            p.addLine(to: CGPoint(x: rect.minX - tr + tipR, y: rect.minY + tipR))
        }

        // Top-left outer tip: small convex arc
        p.addArc(center: CGPoint(x: rect.minX - tr + tipR, y: rect.minY + tipR),
                 radius: tipR,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        p.closeSubpath()
        return p
    }
}
