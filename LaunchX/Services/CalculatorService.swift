import Foundation
import JavaScriptCore

/// Service to handle mathematical expression evaluation
class CalculatorService {
    static let shared = CalculatorService()

    private let context = JSContext()

    private init() {}

    /// Evaluates a string expression and returns the result if it's a valid mathematical formula
    /// - Parameter query: The string to evaluate (e.g., "1+2*3")
    /// - Returns: A formatted string of the result, or nil if not a valid expression
    func evaluate(_ query: String) -> String? {
        // Basic preprocessing: trim and remove spaces for validation
        // Support both ^ and ** for exponentiation
        let sanitized = query.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "^", with: "**")

        if sanitized.isEmpty { return nil }

        // Validation: only allow numbers, basic operators, parentheses, and dots
        // Must contain at least one operator (+, -, *, /, **) to be considered a formula
        let mathRegex = "^[0-9\\+\\-\\*\\/\\(\\)\\.]+$"
        let hasOperator = sanitized.range(of: "[\\+\\-\\*\\/]", options: .regularExpression) != nil

        guard sanitized.range(of: mathRegex, options: .regularExpression) != nil, hasOperator else {
            return nil
        }

        // Don't evaluate if it ends with an operator (incomplete expression)
        if let lastChar = sanitized.last, "+-*/(".contains(lastChar) {
            return nil
        }

        // Use JavaScriptCore for evaluation as it handles decimal division correctly (e.g., 1/2 = 0.5)
        // unlike NSExpression which performs integer division if operands are integers.
        if let result = context?.evaluateScript(sanitized), !result.isUndefined, result.isNumber {
            let doubleValue = result.toDouble()

            // Check for valid number results
            if doubleValue.isNaN || doubleValue.isInfinite {
                return nil
            }

            // Format the result
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 10

            // Use scientific notation for very large or very small numbers to prevent UI overflow
            if abs(doubleValue) >= 1e12 || (abs(doubleValue) > 0 && abs(doubleValue) < 1e-7) {
                formatter.numberStyle = .scientific
                formatter.exponentSymbol = "e"
                formatter.maximumSignificantDigits = 8
            } else {
                formatter.numberStyle = .decimal
                formatter.usesGroupingSeparator = false  // Keep it clean for calculator usage
            }

            return formatter.string(from: NSNumber(value: doubleValue))
        }

        return nil
    }

    /// Checks if a character is a valid math character
    func isMathCharacter(_ char: Character) -> Bool {
        return "0123456789+-*/(). ^".contains(char)
    }
}
