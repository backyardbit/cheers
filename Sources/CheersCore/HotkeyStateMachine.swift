import Foundation

public enum DictationMode: Sendable, Equatable {
    case pushToTalk
    case handsFree
}

public enum HotkeyInput: Sendable, Equatable {
    case triggerDown(shiftHeld: Bool)
    case triggerUp
    case shiftDown
    case otherKeyDown
    case escape
}

public enum HotkeyCommand: Sendable, Equatable {
    case start(DictationMode)
    case lockHandsFree
    case finish
    case cancel
}

public struct HotkeyStateMachine: Sendable {
    public enum State: Sendable, Equatable {
        case idle
        case pushToTalk(startedAt: TimeInterval)
        case handsFree(triggerHeld: Bool)
        case waitingForRelease
    }

    public private(set) var state: State = .idle
    public var minimumHold: TimeInterval

    public init(minimumHold: TimeInterval = 0.25) {
        self.minimumHold = minimumHold
    }

    public mutating func handle(_ input: HotkeyInput, at time: TimeInterval) -> HotkeyCommand? {
        switch (state, input) {
        case (.idle, .triggerDown(let shiftHeld)):
            if shiftHeld {
                state = .handsFree(triggerHeld: true)
                return .start(.handsFree)
            }
            state = .pushToTalk(startedAt: time)
            return .start(.pushToTalk)

        case (.pushToTalk, .shiftDown):
            state = .handsFree(triggerHeld: true)
            return .lockHandsFree

        case (.pushToTalk(let startedAt), .triggerUp):
            state = .idle
            return time - startedAt < minimumHold ? .cancel : .finish

        case (.pushToTalk, .otherKeyDown), (.pushToTalk, .escape):
            state = .idle
            return .cancel

        case (.handsFree(triggerHeld: true), .triggerUp):
            state = .handsFree(triggerHeld: false)
            return nil

        case (.handsFree(triggerHeld: false), .triggerDown):
            state = .waitingForRelease
            return .finish

        case (.handsFree(let triggerHeld), .escape):
            state = triggerHeld ? .waitingForRelease : .idle
            return .cancel

        case (.waitingForRelease, .triggerUp):
            state = .idle
            return nil

        default:
            return nil
        }
    }

    public mutating func reset() {
        state = .idle
    }
}
