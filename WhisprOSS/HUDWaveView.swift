import SwiftUI

struct HUDWaveView: View {
    @ObservedObject var controller: ConversationController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    let width = max(8, CGFloat(controller.level) * geo.size.width)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width, height: 8)
                        .animation(.linear(duration: 0.05), value: controller.level)
                        .accessibilityLabel("Recording level")
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 56)
        .accessibilityElement(children: .combine)
    }
}

#if os(macOS)
import AppKit

final class HUDWindowController: NSWindowController {
    static let shared = HUDWindowController()
    private var hosting: NSHostingView<HUDWaveView>?

    func show(controller: ConversationController, atBottom: Bool = true) {
        print("🖼️ HUD show() called, atBottom=\(atBottom)")
        let content = HUDWaveView(controller: controller)
        if window == nil {
            print("🖼️ Creating new HUD window...")
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 64),
                             styleMask: [.borderless],
                             backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .statusBar
            w.hasShadow = false
            w.ignoresMouseEvents = true
            self.window = w
            print("🖼️ HUD window created")
        }
        let hosting = NSHostingView(rootView: content)
        self.hosting = hosting
        window?.contentView = hosting

        // Get the screen containing the currently focused window
        var activeScreen: NSScreen?

        // Try to get the screen of the frontmost app's main window
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let frontAppWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {

            // Find the frontmost window
            for windowInfo in frontAppWindows {
                if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                   ownerPID == frontApp.processIdentifier,
                   let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                   let x = bounds["X"], let y = bounds["Y"],
                   let width = bounds["Width"], let height = bounds["Height"] {

                    // Find which screen contains this window
                    let windowCenter = CGPoint(x: x + width/2, y: y + height/2)
                    activeScreen = NSScreen.screens.first { screen in
                        screen.frame.contains(windowCenter)
                    }
                    break
                }
            }
        }

        // Fallback to mouse location if we couldn't find the active window's screen
        if activeScreen == nil {
            let mouseLocation = NSEvent.mouseLocation
            activeScreen = NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            }
        }

        // Final fallback to main screen or first available screen
        guard let screen = activeScreen ?? NSScreen.main ?? NSScreen.screens.first,
              let window = window else {
            print("❌ No screen or window available!")
            return
        }

        let margin: CGFloat = 12
        let size = hosting.intrinsicContentSize

        // Calculate position relative to the visible area of the active screen
        // visibleFrame is already in absolute screen coordinates
        let x = screen.visibleFrame.minX + (screen.visibleFrame.width - size.width) / 2
        let y = atBottom ? (screen.visibleFrame.minY + margin) : (screen.visibleFrame.maxY - size.height - margin)

        print("🖼️ Active screen: \(screen.localizedName)")
        print("🖼️ Screen frame: \(screen.frame)")
        print("🖼️ HUD position: (\(x), \(y)), size: \(size)")

        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        window.orderFrontRegardless()
        print("🖼️ HUD ordered front on \(screen.localizedName)")
    }

    func hide() {
        window?.orderOut(nil)
    }
}
#endif
