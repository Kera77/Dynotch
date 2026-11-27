---
name: swiftlint-rules
description: Wingmate's strict SwiftLint limits and Swift 6 pitfalls that broke builds before. Use when ./scripts/check.sh reports lint or compile errors, or before writing a large new Swift file or view.
---

# SwiftLint (strict) and Swift 6 in Wingmate

## Limits
- `file_length` 400, `type_body_length` 250, `function_body_length` 50,
  `cyclomatic_complexity` 10, `function_parameter_count` 5, `large_tuple`: move code into
  extensions or separate files (`NotchController+*.swift`, `NotchView+Pages.swift`,
  `NotesStore+Logic.swift`); turn long switches into lookup tables.
- `line_length` 140; `identifier_name` at least 3 characters (no `to`, `up`, `on`).
- `force_unwrapping`; `sorted_imports` (`@testable import Wingmate` sorts first in tests);
  `empty_count`; `is_disjoint`; `vertical_whitespace`.
- `optional_data_string_conversion`: use `String(bytes:encoding:)`.
- `multiple_closures_with_trailing_closure`: label the closures.
- `legacy_swiftui_aspect_ratio`: use `scaledToFit()`.

## Swift 6 strict concurrency
- A SwiftUI View's (and any `@MainActor` type's) static functions are main-actor isolated;
  calling them from a nonisolated test fails to compile or crashes the test host. Mark pure
  helpers `nonisolated static`.
- Closures passed to `Task.detached` must not capture main-actor state: call plain static
  functions.
- Values captured in `@Sendable` closures must be Sendable; `nonisolated(unsafe)` for
  notification objects.
- A name may clash with SwiftUI (`FocusState` did: renamed to `MacFocus`).

## Swift Testing
- No mutating calls inside `#expect`; compare floating point values with a tolerance.
- Test files go in `WingmateTests/`; XcodeGen picks them up (`check.sh` regenerates the project).
