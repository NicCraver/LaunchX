import AppKit
import SwiftUI

/// A high-performance NSTextField wrapper that doesn't block on input
/// Key optimization: Decouple text input from search execution
/// Input is NEVER blocked - search runs on next RunLoop iteration
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onTextChange: ((String) -> Void)?
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 26, weight: .regular)
        textField.cell?.sendsActionOnEndEditing = false

        // Make it first responder on next run loop
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text is different (avoid feedback loop)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        private var pendingSearchWorkItem: DispatchWorkItem?

        init(_ parent: SearchTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let newText = textField.stringValue

            // Cancel any pending search
            pendingSearchWorkItem?.cancel()

            // Update binding immediately (this is fast)
            parent.text = newText

            // Schedule search on next RunLoop iteration
            // This allows the text field to process the next keystroke first
            let workItem = DispatchWorkItem { [weak self] in
                self?.parent.onTextChange?(newText)
            }
            pendingSearchWorkItem = workItem

            // Use .common mode to ensure it runs even during event tracking
            RunLoop.main.perform {
                if !workItem.isCancelled {
                    workItem.perform()
                }
            }
        }

        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}
