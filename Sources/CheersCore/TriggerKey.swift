import Foundation

public enum TriggerKey: String, CaseIterable, Codable, Sendable {
    case function
    case rightCommand
    case rightOption
    case rightControl

    public var keyCode: UInt16 {
        switch self {
        case .function: 63
        case .rightCommand: 54
        case .rightOption: 61
        case .rightControl: 62
        }
    }

    public var deviceFlag: UInt {
        switch self {
        case .function: 0x80_0000
        case .rightCommand: 0x10
        case .rightOption: 0x40
        case .rightControl: 0x2000
        }
    }

    public var displayName: String {
        switch self {
        case .function: "fn"
        case .rightCommand: "Right ⌘"
        case .rightOption: "Right ⌥"
        case .rightControl: "Right ⌃"
        }
    }

    public func isDown(modifierFlags: UInt) -> Bool {
        modifierFlags & deviceFlag != 0
    }
}
