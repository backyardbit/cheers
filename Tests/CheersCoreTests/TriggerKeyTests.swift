import Foundation
import Testing

@testable import CheersCore

struct TriggerKeyTests {
    @Test func rightCommandIgnoresLeftCommand() throws {
        let key = try #require(TriggerKey(keyCode: 54))
        #expect(!key.isDown(modifierFlags: 0x10_0000 | 0x08))
        #expect(key.isDown(modifierFlags: 0x10_0000 | 0x10))
    }

    @Test func rightControlIgnoresLeftControl() throws {
        let key = try #require(TriggerKey(keyCode: 62))
        #expect(!key.isDown(modifierFlags: 0x4_0000 | 0x01))
        #expect(key.isDown(modifierFlags: 0x4_0000 | 0x2000))
    }

    @Test func functionUsesFunctionFlag() {
        #expect(TriggerKey.function.isDown(modifierFlags: 0x80_0000))
        #expect(!TriggerKey.function.isDown(modifierFlags: 0x2_0000))
    }

    @Test func rejectsShiftCapsLockAndLetters() {
        #expect(TriggerKey(keyCode: 56) == nil)
        #expect(TriggerKey(keyCode: 60) == nil)
        #expect(TriggerKey(keyCode: 57) == nil)
        #expect(TriggerKey(keyCode: 0) == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        let key = try #require(TriggerKey(keyCode: 61))
        let decoded = try JSONDecoder().decode(TriggerKey.self, from: JSONEncoder().encode(key))
        #expect(decoded == key)
        #expect(decoded.displayName == "Right ⌥")
    }
}
