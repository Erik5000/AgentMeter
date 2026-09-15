import AppKit

enum StatusItemClickAction: Equatable {
    case togglePopover
    case showMenu

    static func from(eventType: NSEvent.EventType) -> StatusItemClickAction {
        eventType == .rightMouseUp ? .showMenu : .togglePopover
    }
}
