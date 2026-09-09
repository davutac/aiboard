# Child windows

Use `FloatingWindowManager.showChild` to create or update a named, nonactivating
window attached to a floating parent. The same child ID can be used under different
parents. SwiftUI supplies content; the window API supplies the surrounding surface.

```swift
extension ChildWindowID {
    static let suggestions = ChildWindowID("suggestions")
}

FloatingWindowManager.shared.showChild(
    .suggestions,
    attachedTo: .main,
    configuration: ChildWindowConfiguration(
        title: "Suggestions",
        edge: .top,
        alignment: .center,
        size: .parentWidth(height: 52),
        gap: 8,
        style: ChildWindowStyle(
            background: AnyShapeStyle(.regularMaterial),
            foreground: .primary,
            cornerRadius: 16,
            borderColor: .secondary.opacity(0.2),
            borderWidth: 1,
            contentInsets: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
            hasShadow: true,
            opacity: 1
        )
    )
) {
    SuggestionsView()
}
```

All calls run on the main actor. Configuration is optional; defaults create a
44-point panel above the parent with an 8-point gap and a rounded material surface.

## Placement and sizing

- `edge`: `.top`, `.bottom`, `.left`, or `.right` of the parent.
- `alignment`: `.start`, `.center`, or `.end` along that edge. Start is left on
  horizontal edges and top on vertical edges; these are physical screen positions.
- `size`: `.fixed(CGSize)`, `.parentWidth(height:)`, or `.parentHeight(width:)`.
  Use `.parentWidth()` to match the parent width while fitting content height.
  Sizes include the surface padding. Parent-relative sizes update during resizing.
- `.content` fits both intrinsic dimensions with width capped at the parent.
  Use zero content insets for a window that hugs its controls.
- `.contentWidth(height:)` fits the intrinsic content width, including insets,
  capped at the parent width. It updates as content or parent size changes. Content
  wider than the cap is clipped; use compact content for this mode.
- `gap`: nonnegative distance from the parent.
- `offset`: screen-coordinate adjustment; positive width moves right, positive
  height moves up. Negative offsets are allowed.

Placement stays relative to the parent, including near screen edges. It does not
flip or clamp automatically; a child may extend offscreen. Multiple children do
not automatically stack, so give them distinct edges or offsets when needed.

## Styling and interaction

`ChildWindowStyle` owns background (`AnyShapeStyle`, including colors, gradients,
and materials), foreground, corner radius, border, content insets, native window
shadow, and whole-window opacity. Font and content-specific layout stay in the
SwiftUI view. Avoid duplicating surface backgrounds or padding inside that view.

Children inherit the parent's window level, Spaces behavior, and deactivate
behavior. They cannot take keyboard focus or be dragged independently. Buttons
work without activating the keyboard app; editable, focus-taking windows are not
supported by this API. For dynamically appearing suggestion controls, use the
existing `KeyMouseEventView` input path with accessibility button traits, as in
`SentenceSuggestionButton`. On macOS 27, animated SwiftUI `Button` transitions in
this nonactivating panel can stall `FocusBridge` while rebuilding key-view proxies;
`.focusable(false)` alone does not prevent it.

Set `ignoresMouseEvents: true` for a display-only overlay.
Use `passesThroughEmptyArea: true` to pass clicks to underlying apps outside
views conforming to `WindowMouseInteractiveRegion`. Suggestion controls already
use this marker through `KeyMouseEventNSView`. Mouse monitors are active only
while the child is shown.
The `windowDimensions` environment reflects the child's outer size.

## Lifecycle

```swift
let manager = FloatingWindowManager.shared
manager.hideChild(.suggestions, attachedTo: .main)
manager.removeChild(.suggestions, attachedTo: .main)
let visible = manager.isChildVisible(.suggestions, attachedTo: .main)
```

Calling `showChild` again with the same ID updates configuration and content in
place and makes it eligible to show. It can be called before the parent exists;
the child waits for the parent to be shown.

Hiding a parent temporarily hides its children and restores presented children
when it returns. Explicitly hiding a child retains its content but keeps it hidden
across parent hide/show cycles until another `showChild` call. Removing a child
releases the manager's ownership and content. Unknown IDs are harmless no-ops.

App-specific modes such as Tastko's compact keyboard or lock-screen display should
explicitly hide children they do not want. The companion demonstrates this in
`FloatingWindowController`; its styling preset lives in `TastkoWindowDefinitions`.
