import Testing
@testable import CheersCore

struct HotkeyStateMachineTests {
    @Test func holdAndReleaseFinishesPushToTalk() {
        var machine = HotkeyStateMachine()
        #expect(machine.handle(.fnDown(shiftHeld: false), at: 0) == .start(.pushToTalk))
        #expect(machine.handle(.fnUp, at: 1) == .finish)
        #expect(machine.state == .idle)
    }

    @Test func quickTapCancels() {
        var machine = HotkeyStateMachine()
        _ = machine.handle(.fnDown(shiftHeld: false), at: 0)
        #expect(machine.handle(.fnUp, at: 0.1) == .cancel)
    }

    @Test func fnAsModifierCancels() {
        var machine = HotkeyStateMachine()
        _ = machine.handle(.fnDown(shiftHeld: false), at: 0)
        #expect(machine.handle(.otherKeyDown, at: 0.5) == .cancel)
        #expect(machine.handle(.fnUp, at: 0.6) == nil)
    }

    @Test func shiftFnStartsHandsFreeAndFnFinishes() {
        var machine = HotkeyStateMachine()
        #expect(machine.handle(.fnDown(shiftHeld: true), at: 0) == .start(.handsFree))
        #expect(machine.handle(.fnUp, at: 0.2) == nil)
        #expect(machine.handle(.otherKeyDown, at: 1) == nil)
        #expect(machine.handle(.fnDown(shiftHeld: false), at: 5) == .finish)
        #expect(machine.handle(.fnUp, at: 5.1) == nil)
        #expect(machine.state == .idle)
    }

    @Test func shiftWhileHoldingFnLocksHandsFree() {
        var machine = HotkeyStateMachine()
        _ = machine.handle(.fnDown(shiftHeld: false), at: 0)
        #expect(machine.handle(.shiftDown, at: 0.3) == .lockHandsFree)
        #expect(machine.handle(.fnUp, at: 0.5) == nil)
        #expect(machine.state == .handsFree(fnHeld: false))
    }

    @Test func escapeCancelsHandsFree() {
        var machine = HotkeyStateMachine()
        _ = machine.handle(.fnDown(shiftHeld: true), at: 0)
        _ = machine.handle(.fnUp, at: 0.2)
        #expect(machine.handle(.escape, at: 2) == .cancel)
        #expect(machine.state == .idle)
    }
}
