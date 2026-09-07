import Foundation

// MARK: - FunctionToolbarAction
nonisolated enum FunctionToolbarAction: Equatable {
    case key(Key)
    case system(SystemControl)
}

// MARK: - FunctionToolbarItem
nonisolated struct FunctionToolbarItem: Identifiable {
    let id: Int
    let title: String
    let symbol: String?
    let action: FunctionToolbarAction

    static let functionKeys: [Key] = [
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12,
    ]

    // MARK: - Physical Feedback
    func isPressed(in snapshot: PhysicalKeyboardSnapshot) -> Bool {
        switch action {
        case .key(let key):
            snapshot.pressedKeys.contains(key)
        case .system(let control):
            snapshot.pressedControls.contains(control)
                || (id > 0 && id <= Self.functionKeys.count
                    && snapshot.pressedKeys.contains(Self.functionKeys[id - 1]))
        }
    }

    // MARK: - Rows
    static func items(functionIsActive: Bool) -> [FunctionToolbarItem] {
        let keys =
            functionIsActive
            ? functionKeys.enumerated().map { index, key in
                FunctionToolbarItem(
                    id: index + 1,
                    title: "F\(index + 1)",
                    symbol: nil,
                    action: .key(key)
                )
            }
            : systemItems
        return [FunctionToolbarItem(id: 0, title: "esc", symbol: nil, action: .key(.escape))]
            + keys

    }

    private static let systemItems: [FunctionToolbarItem] = [
        .init(
            id: 1,
            title: "Decrease brightness",
            symbol: "sun.min",
            action: .system(.brightnessDown)
        ),
        .init(
            id: 2,
            title: "Increase brightness",
            symbol: "sun.max",
            action: .system(.brightnessUp)
        ),
        .init(
            id: 3,
            title: "Mission Control",
            symbol: "rectangle.3.group",
            action: .system(.missionControl)
        ),
        .init(id: 4, title: "Spotlight", symbol: "magnifyingglass", action: .system(.spotlight)),
        .init(id: 5, title: "F5", symbol: nil, action: .key(.f5)),
        .init(id: 6, title: "F6", symbol: nil, action: .key(.f6)),
        .init(
            id: 7,
            title: "Previous track",
            symbol: "backward.end",
            action: .system(.previousTrack)
        ),
        .init(id: 8, title: "Play or pause", symbol: "playpause", action: .system(.playPause)),
        .init(id: 9, title: "Next track", symbol: "forward.end", action: .system(.nextTrack)),
        .init(id: 10, title: "Mute", symbol: "speaker.slash", action: .system(.mute)),
        .init(
            id: 11,
            title: "Decrease volume",
            symbol: "speaker.wave.1",
            action: .system(.volumeDown)
        ),
        .init(
            id: 12,
            title: "Increase volume",
            symbol: "speaker.wave.3",
            action: .system(.volumeUp)
        ),
    ]
}
