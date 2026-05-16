import AppKit

enum IslandPosition {

    struct Frames {
        let notchRect: NSRect
    }

    static func detect(in screen: NSScreen) -> Frames {
        let h: CGFloat = 34
        let w: CGFloat = min((screen.auxiliaryTopLeftArea?.width ?? 0) > 0
            ? screen.frame.width - (screen.auxiliaryTopLeftArea!.width) - (screen.auxiliaryTopRightArea!.width)
            : 150, 200)
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h
        return Frames(notchRect: NSRect(x: x, y: y, width: w, height: h))
    }

    static func hasNotch() -> Bool {
        (NSScreen.main?.auxiliaryTopLeftArea?.width ?? 0) > 0
    }
}
