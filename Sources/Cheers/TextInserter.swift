import AppKit
import ApplicationServices

enum InsertionOutcome: Equatable {
    case pasted
    case copied
}

final class TextInserter {
    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let vKeyCode: CGKeyCode = 9

    private var preparedProcesses: Set<pid_t> = []

    func prepareFrontmostApp() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              !preparedProcesses.contains(pid)
        else { return }
        preparedProcesses.insert(pid)
        AXUIElementSetAttributeValue(
            AXUIElementCreateApplication(pid),
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
    }

    func insert(_ text: String) async -> InsertionOutcome {
        guard let element = focusedTextElement() else {
            copyToClipboard(text)
            return .copied
        }
        let payload = needsLeadingSpace(before: text, in: element) ? " " + text : text
        await paste(payload)
        return .pasted
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func focusedTextElement() -> AXUIElement? {
        var value: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        let element = value as! AXUIElement
        return isEditable(element) ? element : nil
    }

    private func isEditable(_ element: AXUIElement) -> Bool {
        if let role = stringAttribute(kAXRoleAttribute, of: element), Self.textRoles.contains(role) {
            return true
        }
        var settable = DarwinBoolean(false)
        let valueSettable = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success
            && settable.boolValue
        var range: CFTypeRef?
        let hasSelection = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success
        if valueSettable && hasSelection {
            return true
        }
        var ancestor: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, "AXEditableAncestor" as CFString, &ancestor) == .success
            && ancestor != nil
    }

    private func needsLeadingSpace(before text: String, in element: AXUIElement) -> Bool {
        guard let first = text.first, first.isLetter || first.isNumber else { return false }

        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else { return false }
        var selection = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selection), selection.location > 0 else { return false }

        var previousRange = CFRange(location: selection.location - 1, length: 1)
        guard let query = AXValueCreate(.cfRange, &previousRange) else { return false }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            query,
            &result
        ) == .success,
            let previous = (result as? String)?.last
        else { return false }
        return !previous.isWhitespace && !"([{\"'“‘/-".contains(previous)
    }

    private func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.transientType)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        let changeCount = pasteboard.changeCount

        postCommandV()

        try? await Task.sleep(for: .milliseconds(500))
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        if !saved.isEmpty {
            pasteboard.writeObjects(saved)
        }
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .privateState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
