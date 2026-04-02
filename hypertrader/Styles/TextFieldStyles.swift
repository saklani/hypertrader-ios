import SwiftUI

// MARK: - Numeric Field Style

/// Right-aligned monospaced text field for numeric input.
/// Usage: `TextField("0.00", text: $value).textFieldStyle(NumericFieldStyle())`
struct NumericFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.body.monospaced())
    }
}

// MARK: - Labeled Numeric Field

/// HStack with a label and a numeric text field.
/// Usage: `LabeledNumericField(label: "Size", text: $sizeText)`
struct LabeledNumericField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = "0.00"

    var body: some View {
        HStack {
            Text(label)
            TextField(placeholder, text: $text)
                .textFieldStyle(NumericFieldStyle())
        }
    }
}

#Preview("Text Field Styles") {
    Form {
        LabeledNumericField(label: "Size", text: .constant("1.5"))
        LabeledNumericField(label: "Price", text: .constant("95000.00"))
        LabeledNumericField(label: "Amount", text: .constant(""))
    }
}
