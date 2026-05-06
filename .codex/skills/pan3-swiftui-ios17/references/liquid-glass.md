# Liquid Glass Reference

## Intent

Use Liquid Glass as the preferred iOS 26+ visual language for Pan3. The app should feel native to current iOS while keeping iOS 17 compatibility through explicit fallbacks.

Use native API first:

- `glassEffect(_:in:)`
- `GlassEffectContainer`
- `.buttonStyle(.glass)`
- `.buttonStyle(.glassProminent)`
- `.interactive()`
- `glassEffectID` with `@Namespace` for morphing transitions

Consult Apple Developer documentation before introducing or changing Liquid Glass API usage.

## Pan3 Usage Targets

Prioritize Liquid Glass for:

- Login form container and submit button.
- Vehicle dashboard range/SOC surface.
- Vehicle control buttons: lock, AC, windows, honk.
- Floating or toolbar-like actions.
- Compact status tiles for windows, doors, tire pressure.
- Bottom or tab-adjacent chrome when custom chrome is needed.

Do not overuse glass for:

- Dense long-form text.
- Data that needs high contrast under stress, such as warnings or error states.
- Large stacked backgrounds behind every card.
- Passive decorative layers that do not improve hierarchy.

## Required Pattern

Always provide an iOS 17 fallback.

```swift
@ViewBuilder
func pan3GlassCard<Content: View>(
    cornerRadius: CGFloat = 24,
    @ViewBuilder content: () -> Content
) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    if #available(iOS 26, *) {
        content()
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
        content()
            .background(.thinMaterial, in: shape)
            .overlay {
                shape.stroke(.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
```

For interactive controls:

```swift
@ViewBuilder
func pan3GlassControl<Content: View>(
    cornerRadius: CGFloat = 18,
    @ViewBuilder content: () -> Content
) -> some View {
    if #available(iOS 26, *) {
        content()
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
        content()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
```

Prefer real button styles where possible:

```swift
if #available(iOS 26, *) {
    Button("登录胖3", action: submit)
        .buttonStyle(.glassProminent)
} else {
    Button("登录胖3", action: submit)
        .buttonStyle(.borderedProminent)
}
```

## Composition Rules

- Wrap nearby glass controls in `GlassEffectContainer` rather than making independent islands.
- Keep glass element count low on scroll-heavy screens.
- Apply `.glassEffect` after size, padding, clip shape, and visual modifiers.
- Use consistent corner radii per hierarchy level:
  - Cards: 24-28
  - Status tiles: 18-20
  - Chips/buttons: capsule or 16-18
  - Icon-only controls: circle
- Keep text outside the most visually busy part of the glass surface when possible.
- Use semantic colors and tints with restraint. Avoid strong saturated glass tints behind dense text.

## Review Checklist

Reject or revise Liquid Glass work if:

- It lacks `#available(iOS 26, *)` fallback.
- It uses custom blur stacks instead of native glass APIs.
- Passive information cards use `.interactive()`.
- Many nested glass surfaces overlap and reduce readability.
- Glass treatment is visually inconsistent across sibling controls.
- Accessibility labels, Dynamic Type behavior, or dark mode contrast regress.
- The same view renders materially different information between iOS 26 and fallback paths.
