import Foundation

public struct TriggerKey: Codable, Hashable, Sendable {
    public let keyCode: UInt16
    public let deviceFlag: UInt
    public let displayName: String

    public static let function = Self(keyCode: 63, deviceFlag: 0x80_0000, displayName: "fn")

    private static let supported: [UInt16: Self] = Dictionary(
        uniqueKeysWithValues: [
            function,
            Self(keyCode: 54, deviceFlag: 0x10, displayName: "Right ⌘"),
            Self(keyCode: 55, deviceFlag: 0x08, displayName: "Left ⌘"),
            Self(keyCode: 61, deviceFlag: 0x40, displayName: "Right ⌥"),
            Self(keyCode: 58, deviceFlag: 0x20, displayName: "Left ⌥"),
            Self(keyCode: 62, deviceFlag: 0x2000, displayName: "Right ⌃"),
            Self(keyCode: 59, deviceFlag: 0x01, displayName: "Left ⌃"),
        ].map { ($0.keyCode, $0) }
    )

    private init(keyCode: UInt16, deviceFlag: UInt, displayName: String) {
        self.keyCode = keyCode
        self.deviceFlag = deviceFlag
        self.displayName = displayName
    }

    public init?(keyCode: UInt16) {
        guard let key = Self.supported[keyCode] else { return nil }
        self = key
    }

    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(UInt16.self)
        guard let key = Self(keyCode: code) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported key code \(code)")
            )
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyCode)
    }

    public func isDown(modifierFlags: UInt) -> Bool {
        modifierFlags & deviceFlag != 0
    }
}
