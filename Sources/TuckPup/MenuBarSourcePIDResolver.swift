import AppKit
import ApplicationServices

/// Resolves the application that originally created a menu bar item.
///
/// Starting in macOS 26, WindowServer reports Control Center as the owner of
/// every menu bar item window. Accessibility still exposes each application's
/// extras menu bar, so matching the accessibility element frame to the
/// WindowServer frame recovers the real source process without making the item
/// visible first.
enum MenuBarSourcePIDResolver {
    struct Window: Sendable {
        let windowID: CGWindowID
        let ownerPID: pid_t
        let bounds: CGRect
    }

    struct Identity: Sendable {
        let pid: pid_t
        let accessibilityTitle: String
        let accessibilityDescription: String
        let accessibilityIdentifier: String
    }

    private struct CachedMatch {
        let identity: Identity
        let bounds: CGRect
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var cache = [CGWindowID: CachedMatch]()

    static func resolve(_ windows: [Window]) -> [CGWindowID: Identity] {
        guard #available(macOS 26.0, *) else {
            return Dictionary(uniqueKeysWithValues: windows.map {
                (
                    $0.windowID,
                    Identity(
                        pid: $0.ownerPID,
                        accessibilityTitle: "",
                        accessibilityDescription: "",
                        accessibilityIdentifier: ""
                    )
                )
            })
        }

        var result = [CGWindowID: Identity]()
        var unresolved = [Window]()

        lock.lock()
        let liveIDs = Set(windows.map(\.windowID))
        cache = cache.filter { liveIDs.contains($0.key) }
        for window in windows {
            if let match = cache[window.windowID], approximatelyEqual(match.bounds, window.bounds) {
                result[window.windowID] = match.identity
            } else {
                unresolved.append(window)
            }
        }
        lock.unlock()

        guard !unresolved.isEmpty, AXIsProcessTrusted() else {
            return result
        }

        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.isFinishedLaunching && !$0.isTerminated
        }

        for application in applications {
            guard !unresolved.isEmpty else { break }
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.35)
            guard let extrasMenuBar = elementAttribute("AXExtrasMenuBar", of: appElement) else {
                continue
            }
            AXUIElementSetMessagingTimeout(extrasMenuBar, 0.35)
            guard let children = elementArrayAttribute(kAXChildrenAttribute, of: extrasMenuBar) else {
                continue
            }

            for child in children {
                AXUIElementSetMessagingTimeout(child, 0.35)
                guard let childFrame = frame(of: child) else { continue }
                guard let matchIndex = unresolved.indices.min(by: { lhs, rhs in
                    centerDistance(unresolved[lhs].bounds, childFrame) <
                    centerDistance(unresolved[rhs].bounds, childFrame)
                }) else { continue }

                let window = unresolved[matchIndex]
                // WindowServer and Accessibility can report different widths
                // for the same status item because their hit regions differ.
                // Their centers remain aligned, including for off-screen
                // items, so center distance is the reliable identity check.
                guard centerDistance(window.bounds, childFrame) <= 2 else { continue }

                let identity = Identity(
                    pid: application.processIdentifier,
                    accessibilityTitle: stringAttribute(kAXTitleAttribute as CFString, of: child),
                    accessibilityDescription: stringAttribute(
                        kAXDescriptionAttribute as CFString,
                        of: child
                    ),
                    accessibilityIdentifier: stringAttribute(
                        kAXIdentifierAttribute as CFString,
                        of: child
                    )
                )
                result[window.windowID] = identity
                lock.lock()
                cache[window.windowID] = CachedMatch(
                    identity: identity,
                    bounds: window.bounds
                )
                lock.unlock()
                unresolved.remove(at: matchIndex)
            }
        }

        return result
    }

    private static func stringAttribute(_ name: CFString, of element: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    private static func elementAttribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func elementArrayAttribute(
        _ name: String,
        of element: AXUIElement
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let values = value as? [AXUIElement]
        else { return nil }
        return values
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(
            unsafeDowncast(positionValue, to: AXValue.self),
            .cgPoint,
            &position
        ),
        AXValueGetValue(
            unsafeDowncast(sizeValue, to: AXValue.self),
            .cgSize,
            &size
        ) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func centerDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        hypot(lhs.midX - rhs.midX, lhs.midY - rhs.midY)
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 1 &&
        abs(lhs.minY - rhs.minY) <= 1 &&
        abs(lhs.width - rhs.width) <= 1 &&
        abs(lhs.height - rhs.height) <= 1
    }
}
