import SwiftUI

struct MenuBarLayoutEditorView: View {
    @ObservedObject var model: MenuBarLayoutModel
    @State private var draggingWindowID: CGWindowID?
    @State private var dragLocation: CGPoint?
    @State private var sectionFrames = [MenuBarItemCategory: CGRect]()
    @State private var itemFrames = [CGWindowID: CGRect]()

    private let tileSize: CGFloat = 44
    private let rowHeight: CGFloat = 70

    var body: some View {
        let strings = Localization.strings
        let _ = model.localizationRevision

        VStack(spacing: 8) {
            permissionBar(strings: strings)

            categoryRow(.visible, title: strings.layoutVisible)
            categoryRow(.hidden, title: strings.layoutHidden)
            categoryRow(.permanent, title: strings.layoutPermanent)
        }
        .coordinateSpace(name: "layoutEditor")
        .onPreferenceChange(SectionFramePreferenceKey.self) { sectionFrames = $0 }
        .onPreferenceChange(ItemFramePreferenceKey.self) { itemFrames = $0 }
        .overlay(alignment: .topLeading) {
            if let draggingWindowID,
               let dragLocation,
               let entry = entry(for: draggingWindowID) {
                tile(for: entry, isDragging: true)
                    .shadow(color: .black.opacity(0.16), radius: 9, y: 4)
                    .offset(
                        x: dragLocation.x - tileSize / 2,
                        y: dragLocation.y - tileSize / 2
                    )
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if model.isRefreshing || model.isMoving || !model.statusMessage.isEmpty {
                HStack(spacing: 6) {
                    if model.isRefreshing || model.isMoving {
                        ProgressView().controlSize(.small)
                    }
                    if !model.statusMessage.isEmpty {
                        Text(model.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(.regularMaterial, in: Capsule())
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private func permissionBar(strings: AppStrings) -> some View {
        if !model.hasAccessibilityPermission || !model.hasScreenRecordingPermission {
            HStack(spacing: 9) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(strings.layoutPermissionHint)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if !model.hasScreenRecordingPermission {
                    Button(strings.layoutAllowScreenRecording) {
                        model.requestScreenRecordingPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                if !model.hasAccessibilityPermission {
                    Button(strings.layoutAllowAccessibility) {
                        model.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)

            Divider().opacity(0.42)
        }
    }

    private func categoryRow(_ category: MenuBarItemCategory, title: String) -> some View {
        let entries = model.entries(in: category).filter { $0.id != draggingWindowID }
        let isDropTarget = dragLocation.map { sectionFrames[category]?.contains($0) == true } ?? false
        let beforeWindowID = isDropTarget ? insertionWindowID(in: category) : nil

        return HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
                .padding(.leading, 14)

            Divider().opacity(0.42)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    if entries.isEmpty && draggingWindowID == nil {
                        Text(Localization.strings.layoutDropHere)
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }

                    ForEach(entries) { entry in
                        if isDropTarget && beforeWindowID == entry.id {
                            insertionSlot
                        }

                        tile(for: entry, isDragging: false)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: ItemFramePreferenceKey.self,
                                        value: [entry.id: geometry.frame(in: .named("layoutEditor"))]
                                    )
                                }
                            }
                            .highPriorityGesture(dragGesture(for: entry))
                    }

                    if isDropTarget && beforeWindowID == nil {
                        insertionSlot
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: rowHeight)
            }
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(isDropTarget ? 0.075 : 0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.primary.opacity(isDropTarget ? 0.12 : 0.055), lineWidth: 0.5)
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SectionFramePreferenceKey.self,
                    value: [category: geometry.frame(in: .named("layoutEditor"))]
                )
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var insertionSlot: some View {
        Capsule()
            .fill(Color.primary.opacity(0.48))
            .frame(width: 2, height: 30)
            .frame(width: 8, height: tileSize)
            .transition(.opacity)
    }

    private func tile(for entry: MenuBarLayoutEntry, isDragging: Bool) -> some View {
        MenuBarItemTile(
            entry: entry,
            isDragging: isDragging,
            onMove: { destination in
                withAnimation(.snappy(duration: 0.22)) {
                    model.move(windowID: entry.id, to: destination)
                }
            }
        )
        .frame(width: tileSize, height: tileSize)
    }

    private func dragGesture(for entry: MenuBarLayoutEntry) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("layoutEditor"))
            .onChanged { value in
                if draggingWindowID == nil { draggingWindowID = entry.id }
                dragLocation = value.location
            }
            .onEnded { value in
                finishDrag(windowID: entry.id, at: value.location)
            }
    }

    private func finishDrag(windowID: CGWindowID, at location: CGPoint) {
        defer {
            withAnimation(.easeOut(duration: 0.12)) {
                draggingWindowID = nil
                dragLocation = nil
            }
        }

        guard let destination = MenuBarItemCategory.allCases.first(where: {
            sectionFrames[$0]?.contains(location) == true
        }) else { return }

        withAnimation(.snappy(duration: 0.22)) {
            model.move(
                windowID: windowID,
                to: destination,
                before: insertionWindowID(in: destination, at: location)
            )
        }
    }

    private func insertionWindowID(
        in category: MenuBarItemCategory,
        at location: CGPoint? = nil
    ) -> CGWindowID? {
        guard let location = location ?? dragLocation else { return nil }
        return model.entries(in: category)
            .filter { $0.id != draggingWindowID }
            .first(where: { candidate in
                guard let frame = itemFrames[candidate.id] else { return false }
                return location.x < frame.midX
            })?.id
    }

    private func entry(for windowID: CGWindowID) -> MenuBarLayoutEntry? {
        MenuBarItemCategory.allCases
            .flatMap { model.entries(in: $0) }
            .first { $0.id == windowID }
    }
}

private struct MenuBarItemTile: View {
    let entry: MenuBarLayoutEntry
    let isDragging: Bool
    let onMove: (MenuBarItemCategory) -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    Color.primary.opacity(
                        isDragging ? 0.10 : (isHovering ? 0.055 : 0)
                    )
                )

            itemImage
                .frame(
                    width: entry.image?.isTemplate == true ? 25 : 32,
                    height: entry.image?.isTemplate == true ? 25 : 32
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    Color.primary.opacity(isDragging ? 0.20 : 0),
                    lineWidth: 0.75
                )
        }
        .scaleEffect(isHovering && !isDragging ? 1.025 : 1)
        .opacity(isDragging ? 0.95 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(entry.name)
        .contextMenu {
            ForEach(MenuBarItemCategory.allCases) { category in
                Button(categoryTitle(category)) {
                    onMove(category)
                }
            }
        }
    }

    @ViewBuilder
    private var itemImage: some View {
        if let image = entry.image {
            if image.isTemplate {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private func categoryTitle(_ category: MenuBarItemCategory) -> String {
        let strings = Localization.strings
        switch category {
        case .permanent: return strings.layoutPermanent
        case .hidden: return strings.layoutHidden
        case .visible: return strings.layoutVisible
        }
    }
}

private struct SectionFramePreferenceKey: PreferenceKey {
    static let defaultValue = [MenuBarItemCategory: CGRect]()

    static func reduce(value: inout [MenuBarItemCategory: CGRect], nextValue: () -> [MenuBarItemCategory: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ItemFramePreferenceKey: PreferenceKey {
    static let defaultValue = [CGWindowID: CGRect]()

    static func reduce(value: inout [CGWindowID: CGRect], nextValue: () -> [CGWindowID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
