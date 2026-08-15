# About Page Design QA

## Source of visual truth

- User-provided inline reference screenshot: QQ mobile About page in dark mode.
- Reference dimensions: approximately 922 × 2048 px.
- The reference was used for information hierarchy only: centered identity artwork, product name, grouped information cards, and a legal footer.
- The implementation intentionally retains the existing app logo, Material 3 components, and the app's dynamic color system instead of copying QQ branding or visual assets.

## Implementation captures

- Light mode: `mobile/tool/goldens/about_page_light.png`
- Dark mode: `mobile/tool/goldens/about_page_dark.png`
- Capture viewport: 393 × 852 logical px at device-pixel ratio 1.
- Captured state: About page root, motion at rest, no touch press.

## Full-view comparison

The implementation preserves the reference's top-to-bottom hierarchy while adapting it to this product: Material app bar, large centered app identity, grouped version/product/license cards, and an open-source footer. The logo is given more surrounding breathing room and a circular dynamic-color halo so it reads as part of the existing Material You design language rather than a QQ-style clone.

## Focused-region checks

- Hero: centered, uncropped 154 px source logo inside a 210 px tonal halo; elevation and 44 px corner radius remain visible in both themes.
- Interaction: touch drag, tap compression, haptic feedback, 3D perspective, and gyroscope input all converge on the same bounded tilt transform.
- Cards: consistent 20 px page gutters, 14 px inter-card spacing, semantic Material icons, dividers, and minimum ListTile touch targets.
- Typography: Material text-theme roles and weight hierarchy are used; no custom font is bundled.
- Color: all surfaces and foregrounds derive from `ColorScheme`, so wallpaper-derived Material You colors and light/dark modes remain supported.
- Copy: version, product purpose, project-license status, and third-party license access are explicit. No website, update, or support destination is fabricated.
- Image quality: the existing 1254 px app icon is displayed with `BoxFit.cover` and anti-aliased clipping; it remains sharp at the rendered size.

## Findings and iteration history

1. Initial capture showed the first frame before the app icon asset was decoded.
2. Added deterministic per-capture image preloading; the final light and dark captures contain the real app logo and pass a clean repeat comparison.
3. Flutter's headless golden-test font does not include Traditional Chinese glyphs, so Chinese text appears as fallback boxes in the stored QA captures. This is a capture-environment limitation; Android renders the same strings with the device's CJK system font, and widget tests verify the actual Traditional Chinese text.
4. No P0, P1, or P2 layout, interaction, contrast, clipping, or navigation defects remain in the inspected state.

final result: passed
