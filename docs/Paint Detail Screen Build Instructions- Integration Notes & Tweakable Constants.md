# Paint Detail Screen Build Instructions: Integration Notes & Tweakable Constants

## Rounded Corner Underlay

Each Similar paint card renders a colored underlay (using a `Positioned.fill` behind the card) so that its rounded bottom corners reveal the color of the card beneath instead of a white background. For the top card, we use the base paint’s color (the hero background) as the underlay, ensuring no white leaks around the hero. This makes the stack appear like physical paint chips, with each card’s color peeking out under the one above it.

## Smooth Expansion/Collapse

Tapping a card toggles its expansion with an animated height (`AnimatedContainer`) and content reveal (`AnimatedSize`). The expanded card’s detailed info (hex code, paint code, action buttons) fades in smoothly. If an expanded card is near the top, we automatically scroll it into view (e.g., `Scrollable.ensureVisible`/programmatic scroll) so its content isn’t hidden under the top app bar or tabs.

## Stacking & Overlap

We maintain a stacked layout and keep the top card tucked under the hero. Cards overlap vertically by ~22 px by default, slightly less than the 28 px corner radius, allowing a subtle peek of the card behind. The second card in the stack gets an additional 14 px of breathing room to ensure its title text isn’t obscured by the card above.

Key spacing constants (as implemented):

```
_kCardBottomRadius   = 28.0   // rounded bottom corner radius for all cards
_kOverlap            = 22.0   // base vertical overlap (radius - 6 px)
_kSecondExtraRoom    = 14.0   // extra room specifically for the second card
_kFirstOnTop         = false  // natural list order for intuitive scrolling
```

## Hero Integration

The top card is positioned to appear tucked under the hero image’s curved bottom. We align the card stack visually with the SliverAppBar’s 28 px bottom radius. When the first card expands, we insert a dynamic spacer above it so the expanded content slides fully into view instead of growing upward under the header.

## Subtle Parallax Effect

As you scroll, each card can shift vertically at a slightly different rate, creating a depth effect. Use an index-based parallax factor starting at 0.06 for the bottom card and incrementing by 0.015 for each card above. The scroll offset is multiplied by this factor to offset the card (`Transform.translate`), clamped to ~40 px to avoid excessive movement.

Suggested tunables (set to 0 to disable):

```
_parallaxBase      = 0.06
_parallaxIncrement = 0.015
_parallaxClampPx   ≈ 40.0
```

## Performance

The stacking and animations use simple containers with implicit animations. Rebuilds are localized to the list; the scroll listener only updates state for glow indicators/parallax when needed. Overlap rendering uses an underlay (no heavy clipping besides rounded corners), remaining efficient in both light and dark themes. In testing with hundreds of items, scrolling and interactions remain smooth.

## Theming

Works well for light and dark modes. Foreground colors (text/icons) are chosen based on each card’s background brightness via `ThemeData.estimateBrightnessForColor`. Semi-transparent overlays (e.g., `Colors.white.withAlpha(20)`) remain subtle across themes, and we reuse theme surfaces/outlines (e.g., tabs and usage sections) for consistency.

## Adjustable Parameters

- Card radius (`_kCardBottomRadius`): 28.0 by default. If changed, match the SliverAppBar’s bottom radius for a seamless edge.
- Overlap (`_kOverlap`): radius minus 6 (22.0). Increase for tighter stack (more overlap) or decrease for more separation.
- Second card spacing (`_kSecondExtraRoom`): 14.0 by default; tweak if the second card’s text needs more/less room.
- Parallax factors: start at 0.06 with +0.015 increments; lower for more subtle movement or set to zero to disable.
- Base/expanded heights: collapsed ≈ 10% of screen height (min 80 px, max 180 px); expanded ≈ 22% (min 180 px, max 300 px). Adjust in `_SimilarTabState.build` as needed.

All other tabs and functionalities remain intact. The Similar tab delivers a polished UX: no white corner artifacts, smooth card expansion, and a dynamic stacked-scroll effect that makes the paint chips feel tangible and interactive.
