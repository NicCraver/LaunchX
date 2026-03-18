## ADDED Requirements

### Requirement: Image Utilities
The system SHALL provide ImageUtils class with methods for common image operations used across the codebase.

#### Scenario: Resize icon to specific size
- **WHEN** resizeIcon is called with an NSImage and target size
- **THEN** the system returns a new NSImage scaled to the exact dimensions

#### Scenario: Resize maintains aspect ratio
- **WHEN** resizeIcon is called with aspectRatio parameter set to true
- **THEN** the system returns an NSImage that fits within target size while maintaining original aspect ratio

#### Scenario: Resize handles invalid input
- **WHEN** resizeIcon is called with size <= 0
- **THEN** the system returns the original image unchanged

### Requirement: KeyCode Utilities
The system SHALL provide KeyCodeUtils class for keyboard-related conversions and formatting.

#### Scenario: Convert keyCode to display string
- **WHEN** keyString(for:) is called with a valid keyCode
- **THEN** the system returns the human-readable character (e.g., keyCode 0 → "A")

#### Scenario: Convert modifiers to symbols
- **WHEN** modifierSymbols(for:) is called with Carbon modifier flags
- **THEN** the system returns an array of modifier symbols in order [⌃, ⌥, ⇧, ⌘]

#### Scenario: Convert Cocoa to Carbon modifiers
- **WHEN** carbonModifiers(from:) is called with NSEvent.ModifierFlags
- **THEN** the system returns equivalent Carbon modifier flags (UInt32)

#### Scenario: Format hotkey for display
- **WHEN** formatHotKey(keyCode:modifiers:) is called
- **THEN** the system returns a formatted string like "⌃⌥A"

### Requirement: String Utilities
The system SHALL provide StringUtils class for common string operations.

#### Scenario: Validate URL format
- **WHEN** isValidURL is called with a string
- **THEN** the system returns true if the string is a valid URL format

#### Scenario: Truncate long strings
- **WHEN** truncate is called with maxLength parameter
- **THEN** the system returns the string truncated to maxLength with "..." appended if needed

#### Scenario: Remove whitespace
- **WHEN** trimmed is called on a string
- **THEN** the system returns the string with leading and trailing whitespace removed

### Requirement: Validation Utilities
The system SHALL provide ValidationUtils class for input validation logic.

#### Scenario: Validate hotkey combination
- **WHEN** isValidHotKeyCombination is called with keyCode and modifiers
- **THEN** the system returns true only if modifiers are not empty (prevents single-key hotkeys)

#### Scenario: Validate alias format
- **WHEN** isValidAlias is called with a string
- **THEN** the system returns true if the string contains only alphanumeric characters and is 1-10 characters long

#### Scenario: Validate time span
- **WHEN** isValidTimeSpan is called with minutes
- **THEN** the system returns true if the value is within acceptable range (1-60 minutes)

### Requirement: NSImage Extensions
The system SHALL provide NSImage extension methods for common image operations.

#### Scenario: Resize via extension method
- **WHEN** image.resized(to:) is called
- **THEN** the system returns a resized NSImage using ImageUtils.resizeIcon

#### Scenario: Tint image with color
- **WHEN** image.tinted(with:) is called with an NSColor
- **THEN** the system returns a new NSImage with the specified tint color applied

### Requirement: String Extensions
The system SHALL provide String extension methods for common string operations.

#### Scenario: URL validation via extension
- **WHEN** string.isValidURL is accessed
- **THEN** the system returns the result of StringUtils.isValidURL

#### Scenario: Truncation via extension
- **WHEN** string.truncated(to:) is called
- **THEN** the system returns the result of StringUtils.truncate
