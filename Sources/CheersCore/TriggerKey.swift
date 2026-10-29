import Foundation

public struct TriggerKey: Codable, Hashable, Sendable {
    public let keyCode: UInt16

    public static let function = TriggerKey(uncheckedKeyCode: 63)

    private static let modifiers: [UInt16: (flag: UInt, name: String)] = [
        63: (0x80_0000, "fn"),
        54: (0x10, "Right ⌘"),
        55: (0x08, "Left ⌘"),
        61: (0x40, "Right ⌥"),
        58: (0x20, "Left ⌥"),
        62: (0x2000, "Right ⌃"),
        59: (0x01, "Left ⌃"),
    ]

    public init?(keyCode: UInt16) {
        guard Self.modifiers[keyCode] != nil else { return nil }
        self.keyCode = keyCode
    }

    private init(uncheckedKeyCode: UInt16) {
        keyCode = uncheckedKeyCode
    }

    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(UInt16.self)
        guard Self.modifiers[code] != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported key code \(code)"))
        }
        keyCode = code
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyCode)
    }

    public var deviceFlag: UInt { Self.modifiers[keyCode]!.flag }

    public var displayName: String { Self.modifiers[keyCode]!.name }

    public func isDown(modifierFlags: UInt) -> Bool {
        modifierFlags & deviceFlag != 0
    }
}
