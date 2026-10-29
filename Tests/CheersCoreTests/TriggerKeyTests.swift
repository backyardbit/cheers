import Testing
@testable import CheersCore

struct TriggerKeyTests {
    @Test func rightCommandIgnoresLeftCommand() {
        let leftCommandOnly: UInt = 0x10_0000 | 0x08
        let rightCommand: UInt = 0x10_0000 | 0x10
        #expect(!TriggerKey.rightCommand.isDown(modifierFlags: leftCommandOnly))
        #expect(TriggerKey.rightCommand.isDown(modifierFlags: rightCommand))
    }

    @Test func rightOptionIgnoresLeftOption() {
        #expect(!TriggerKey.rightOption.isDown(modifierFlags: 0x8_0000 | 0x20))
        #expect(TriggerKey.rightOption.isDown(modifierFlags: 0x8_0000 | 0x40))
    }

    @Test func functionUsesFunctionFlag() {
        #expect(TriggerKey.function.isDown(modifierFlags: 0x80_0000))
        #expect(!TriggerKey.function.isDown(modifierFlags: 0x2_0000))
    }
}
