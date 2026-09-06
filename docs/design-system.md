# Keyboard design system

The keyboard uses rounded, flat keycaps on a neutral chassis. Keys, predictions, and window chrome share the same palette and typography. Imported layouts still determine key placement and actions.

## Where to make changes

| Concern | Source |
| --- | --- |
| Light and dark colors | `Aiboard/Assets.xcassets/Keyboard*.colorset` |
| Semantic palette, dimensions and fonts | `Aiboard/DesignSystem/KeyboardDesign.swift` |
| Solid key fill, border, hover, press, and active states | `Aiboard/DesignSystem/KeycapSurface.swift` |
| Imported key labels, sizing, and active indicator | `Aiboard/Components/Keyboard/PanelEditorKeycap.swift` |
| SwiftUI keycap buttons | `Aiboard/DesignSystem/KeycapButtonStyle.swift` |
| Light and dark component previews | `Aiboard/DesignSystem/KeyboardDesignPreview.swift` |

Use `KeyboardDesign.Palette` in keyboard views. Default colors have an Any Appearance value for light mode and a Dark value in the asset catalog. Imported `DisplayColor` fills the entire key surface, and `FontColor` colors both primary and secondary labels, preserving their sRGB components and alpha in either appearance. Missing profile colors use the adaptive defaults. SwiftUI follows the system appearance; the app does not force a color scheme. Adjust both asset variants when changing a color, then check both previews. Keep normal key-label contrast at least 4.5:1.

The palette separates chassis and chrome, solid key fill, primary and secondary labels, borders, and separators. Active modifiers use a green border and indicator without replacing their profile fill. Hover softens the solid fill and strengthens the border. Pressing a key depresses its visual surface with a short animation; its pointer region stays fixed. Keys, suggestions, and the keyboard chassis use solid colors without gradients or glows. The titlebar alone blends vertically from chrome to chassis, with no bottom divider, to join the keyboard background seamlessly.

## Components and behavior

Use `KeycapSurface` as a background, passing a shape and the current interaction state. It handles appearance only. Input delivery, accessibility labels, sounds, and focus remain with the existing control. `KeycapButtonStyle` applies this surface to SwiftUI controls such as the language switch. Rectangle and ISO Return keys share the surface. Visual insets and rounded corners do not shrink the existing pointer regions. The titlebar centers the selected profile name without an icon or extra label; its menu switches profiles, opens macOS Panel Editor, and reloads imported profiles.

Use the metrics and typography in `KeyboardDesign` rather than introducing local copies. Key labels scale with the imported panel. The panel keeps a 5-point outer inset. Key columns fill the available width so the side margins match the bottom inset, while vertical spacing and row heights stay unchanged. Prediction buttons keep a 32-point height, content-sized width, and left alignment. The row shows as many complete buttons as fit, without scrolling or changing its height.

Prediction changes update without fades. Reduce Motion disables keypress animation, and Increased Contrast strengthens key borders. Do not animate pointer regions or replace a prediction while it is pressed.

To add a visual state, extend `KeycapSurface` and its previews. To add a color role, create a named color asset with both appearances and expose it through `KeyboardDesign.Palette`. Avoid per-screen themes or duplicated keycap drawing code.

The optional function toolbar sits directly below the titlebar and above predictions. Its complete height comes from the scaled keycap height plus vertical insets. Display-synchronized frame updates drive its clipped reveal and the native window geometry, keeping the main key area stable. Constraints and saved geometry update at completion. One permanent toggle sits to the right of the language selector in the prediction row; imported toolbar toggles are hidden without reflowing the remaining keys. System controls are the normal layer; the existing one-shot Fn modifier exposes F1–F12.
