import AppKit

private final class ShelfScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        guard let documentView else {
            super.scrollWheel(with: event)
            return
        }

        let rawDelta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY
        guard rawDelta != 0 else {
            super.scrollWheel(with: event)
            return
        }

        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.35 : 13
        let maximumX = max(0, documentView.frame.width - contentView.bounds.width)
        var origin = contentView.bounds.origin
        origin.x = min(maximumX, max(0, origin.x - rawDelta * multiplier))
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }
}

private final class ShelfIconButton: NSButton {
    private var hoverArea: NSTrackingArea?
    private var isHovering = false

    override var wantsUpdateLayer: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        alphaValue = 1
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        alphaValue = 0.9
        needsDisplay = true
    }

    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = isHovering
            ? NSColor.labelColor.withAlphaComponent(0.09).cgColor
            : NSColor.clear.cgColor
        layer?.borderWidth = 0
    }
}

@MainActor
final class HiddenIconsShelfController: NSObject {
    private static let cornerRadius: CGFloat = 13

    private let panel: NSPanel
    private let rootStack = NSStackView()
    private let regularStack = NSStackView()
    private let permanentStack = NSStackView()
    private let regularScroll = ShelfScrollView()
    private let permanentScroll = ShelfScrollView()

    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var itemByButton = [ObjectIdentifier: ManagedMenuBarItem]()
    private var onSelect: ((ManagedMenuBarItem) -> Void)?
    private weak var anchorWindow: NSWindow?
    private var regularContentWidth: CGFloat = 0
    private var permanentContentWidth: CGFloat = 0

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    func show(
        regularItems: [ManagedMenuBarItem],
        permanentItems: [ManagedMenuBarItem],
        anchoredTo anchorWindow: NSWindow?,
        onSelect: @escaping (ManagedMenuBarItem) -> Void
    ) {
        self.anchorWindow = anchorWindow
        self.onSelect = onSelect
        itemByButton.removeAll()

        regularContentWidth = rebuild(stack: regularStack, items: regularItems)
        permanentContentWidth = rebuild(stack: permanentStack, items: permanentItems)
        updatePanelFrame()
        panel.orderFrontRegardless()
        startOutsideClickMonitors()
    }

    func close() {
        panel.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private func configurePanel() {
        panel.level = .mainMenu + 1
        panel.isFloatingPanel = true
        // A borderless window's standard shadow follows the rectangular window
        // frame, not the rounded glass contour.  The glass view provides its own
        // edge treatment, so the window shadow must stay off.
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        configure(scrollView: regularScroll, documentView: regularStack)
        configure(scrollView: permanentScroll, documentView: permanentStack)

        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        let divider = NSBox()
        divider.boxType = .separator

        rootStack.spacing = 2
        rootStack.edgeInsets = NSEdgeInsets(top: 5, left: 7, bottom: 5, right: 7)
        rootStack.addArrangedSubview(regularScroll)
        rootStack.addArrangedSubview(divider)
        rootStack.addArrangedSubview(permanentScroll)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let contentContainer = NSView()
        contentContainer.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            regularScroll.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            permanentScroll.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -8),
            regularScroll.heightAnchor.constraint(equalToConstant: 32),
            permanentScroll.heightAnchor.constraint(equalToConstant: 32)
        ])

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.cornerRadius = Self.cornerRadius
            glassView.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.72)
            glassView.contentView = contentContainer
            panel.contentView = glassView
        } else {
            let effectView = NSVisualEffectView()
            effectView.material = .popover
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = Self.cornerRadius
            effectView.layer?.cornerCurve = .continuous
            effectView.layer?.masksToBounds = true
            effectView.layer?.borderWidth = 0.5
            effectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.32).cgColor
            effectView.addSubview(contentContainer)
            contentContainer.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentContainer.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                contentContainer.topAnchor.constraint(equalTo: effectView.topAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
            ])
            panel.contentView = effectView
        }
    }

    private func configure(scrollView: NSScrollView, documentView: NSStackView) {
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false

        documentView.orientation = .horizontal
        documentView.alignment = .centerY
        documentView.spacing = 4
        documentView.edgeInsets = NSEdgeInsets(top: 0, left: 1, bottom: 0, right: 5)
        scrollView.documentView = documentView
    }

    @discardableResult
    private func rebuild(stack: NSStackView, items: [ManagedMenuBarItem]) -> CGFloat {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        var measuredWidth: CGFloat = 0
        if items.isEmpty {
            let label = NSTextField(labelWithString: "—")
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .tertiaryLabelColor
            label.alignment = .left
            label.frame = NSRect(x: 0, y: 0, width: 34, height: 32)
            stack.addArrangedSubview(label)
            measuredWidth = 34
        } else {
            for item in items {
                let button = ShelfIconButton(title: "", target: self, action: #selector(itemPressed(_:)))
                button.isBordered = false
                let image = MenuBarItemBridge.image(for: item)
                    ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
                button.image = image
                button.imagePosition = .imageOnly
                button.toolTip = item.displayName
                button.setButtonType(.momentaryChange)
                button.alphaValue = 0.9
                button.translatesAutoresizingMaskIntoConstraints = false
                let naturalWidth = min(48, max(36, (image?.size.width ?? 22) + 12))
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: naturalWidth),
                    button.heightAnchor.constraint(equalToConstant: 32)
                ])
                measuredWidth += naturalWidth
                itemByButton[ObjectIdentifier(button)] = item
                stack.addArrangedSubview(button)
            }
            measuredWidth += CGFloat(max(0, items.count - 1)) * stack.spacing
        }

        measuredWidth += stack.edgeInsets.left + stack.edgeInsets.right
        stack.frame = NSRect(
            origin: .zero,
            size: NSSize(width: max(42, measuredWidth), height: 32)
        )
        return max(42, measuredWidth)
    }

    private func updatePanelFrame() {
        let screen = anchorWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let naturalWidth = max(regularContentWidth, permanentContentWidth) + 14
        let width = min(640, max(190, naturalWidth))
        let height: CGFloat = 80
        let anchorMidX = anchorWindow?.frame.midX ?? screen.frame.maxX - 80
        let x = min(
            max(screen.frame.minX + 12, anchorMidX - width + 48),
            screen.frame.maxX - width - 12
        )
        let menuBarHeight = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        let top = screen.frame.maxY - menuBarHeight - 5
        panel.setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: true)
    }

    @objc private func itemPressed(_ sender: NSButton) {
        guard let item = itemByButton[ObjectIdentifier(sender)] else { return }
        close()
        onSelect?(item)
    }

    private func startOutsideClickMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.panel { self.close() }
            return event
        }
    }
}
