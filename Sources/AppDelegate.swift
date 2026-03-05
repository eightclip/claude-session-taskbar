import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var usageTracker: UsageTracker!
    private var updateTimer: Timer?
    private var lastDisplayedPercentage: Int = -1
    private var eventMonitor: Any?

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        usageTracker = UsageTracker()
        setupStatusBar()
        setupPopover()
        startUpdateTimer()
        setupEventMonitor()
    }

    // MARK: - Status Bar
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateStatusBarImage()
        }
    }

    func updateStatusBarImage() {
        let percentage = usageTracker.sessionPercentage
        let displayPercentage = Int(min(percentage, 1.0) * 100)

        // Only redraw if percentage changed
        guard displayPercentage != lastDisplayedPercentage else { return }
        lastDisplayedPercentage = displayPercentage

        let image = createStatusBarImage(
            progress: min(percentage, 1.0),
            percentText: displayPercentage
        )
        statusItem.button?.image = image
    }

    private func createStatusBarImage(progress: Double, percentText: Int) -> NSImage {
        let barWidth: CGFloat = 52
        let totalWidth: CGFloat = barWidth + 30 // bar + text
        let height: CGFloat = 22
        let barHeight: CGFloat = 12
        let barY: CGFloat = (height - barHeight) / 2
        let cornerRadius: CGFloat = 4
        let inset: CGFloat = 1.5

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { rect in

            // -- Small Claude dot --
            let dotSize: CGFloat = 6
            let dotRect = NSRect(x: 0, y: (height - dotSize) / 2, width: dotSize, height: dotSize)
            let dotGradient = NSGradient(starting: Theme.coralNS, ending: Theme.amberNS)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            dotGradient?.draw(in: dotPath, angle: 45)

            let barX: CGFloat = dotSize + 4

            // -- Bar background --
            let bgRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor(white: 0.0, alpha: 0.18).setFill()
            bgPath.fill()

            // Subtle border
            NSColor(white: 1.0, alpha: 0.08).setStroke()
            bgPath.lineWidth = 0.5
            bgPath.stroke()

            // -- Bar fill --
            if progress > 0.005 {
                let fillWidth = max(cornerRadius * 2, (barWidth - inset * 2) * CGFloat(progress))
                let fillRect = NSRect(x: barX + inset, y: barY + inset, width: fillWidth, height: barHeight - inset * 2)
                let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)

                let gradient = Theme.progressGradientNS(for: progress)
                gradient.draw(in: fillPath, angle: 0)
            }

            // -- Percentage text --
            let text = "\(percentText)%"
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor(white: 0.35, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textX = barX + barWidth + 4
            let textY = (height - textSize.height) / 2
            (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Popover
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)

        let contentView = PopoverView(tracker: usageTracker)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            usageTracker.refresh()
            updateStatusBarImage()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Bring popover to front
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
            }
        }
    }

    // MARK: - Update Timer
    private func startUpdateTimer() {
        let interval = TimeInterval(usageTracker.config.refreshIntervalSeconds)
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.usageTracker.refresh()
            // Delay image update slightly to let async API response arrive
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.updateStatusBarImage()
            }
        }
    }

    // MARK: - Click Outside to Close
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
}
