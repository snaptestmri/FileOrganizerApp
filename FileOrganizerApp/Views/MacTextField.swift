import SwiftUI
import AppKit

/// AppKit text field — reliable keyboard focus when the app is launched from Terminal (`swift run`).
struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusOnAppear: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if focusOnAppear, context.coordinator.requestFocus {
            context.coordinator.requestFocus = false
            DispatchQueue.main.async {
                AppActivation.activate()
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, requestFocus: focusOnAppear)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var requestFocus: Bool

        init(text: Binding<String>, requestFocus: Bool) {
            _text = text
            self.requestFocus = requestFocus
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}
