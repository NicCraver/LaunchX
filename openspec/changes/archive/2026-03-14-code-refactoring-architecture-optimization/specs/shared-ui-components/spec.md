## ADDED Requirements

### Requirement: HotKey Recorder Component
The system SHALL provide a reusable HotKeyRecorderView component that can be used across all settings views requiring hotkey input.

#### Scenario: Component displays current hotkey
- **WHEN** a hotkey is configured (keyCode != 0)
- **THEN** the component displays modifier symbols and key character in KeyCap style

#### Scenario: Component opens recorder popover
- **WHEN** user clicks the hotkey button
- **THEN** the system opens a popover for recording new hotkey

#### Scenario: Component detects conflicts
- **WHEN** user records a hotkey that conflicts with existing hotkeys
- **THEN** the component displays conflict message with the conflicting feature name

#### Scenario: Component clears hotkey
- **WHEN** user presses Delete or Backspace in recorder
- **THEN** the component clears the hotkey (sets keyCode and modifiers to 0)

### Requirement: Settings Row Component
The system SHALL provide a reusable SettingsRow component for consistent label-content layout across all settings views.

#### Scenario: Row displays label and content
- **WHEN** a settings row is rendered
- **THEN** the label is right-aligned with configurable width and content is left-aligned

#### Scenario: Row supports custom content
- **WHEN** developer provides ViewBuilder content
- **THEN** the row renders any SwiftUI view as content (TextField, Toggle, Picker, etc.)

### Requirement: KeyCap View Component
The system SHALL provide a reusable KeyCapView component for displaying keyboard keys in a consistent visual style.

#### Scenario: KeyCap displays modifier symbols
- **WHEN** rendering modifier keys (⌘, ⌃, ⌥, ⇧)
- **THEN** the component displays the symbol in a rounded rectangle with accent color background

#### Scenario: KeyCap displays character keys
- **WHEN** rendering character keys (A-Z, 0-9, etc.)
- **THEN** the component displays the character in a rounded rectangle with accent color background

### Requirement: Component Reusability
All shared components MUST be usable in at least 3 different settings views without modification.

#### Scenario: HotKeyRecorder used in multiple views
- **WHEN** BookmarkSearchSettingsView, TwoFactorAuthSettingsView, and other views use HotKeyRecorderView
- **THEN** all views display identical hotkey recording behavior and UI

#### Scenario: SettingsRow used in multiple views
- **WHEN** multiple settings views use SettingsRow with different label widths
- **THEN** each view can configure its own label width while maintaining consistent layout

### Requirement: Component API Consistency
All shared components SHALL follow SwiftUI best practices with @Binding for two-way data flow.

#### Scenario: HotKeyRecorder updates parent state
- **WHEN** user records a new hotkey in HotKeyRecorderView
- **THEN** the parent view's @Binding variables are updated immediately

#### Scenario: SettingsRow passes through content
- **WHEN** developer provides content closure to SettingsRow
- **THEN** the content is rendered without modification using @ViewBuilder
