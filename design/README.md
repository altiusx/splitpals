# App icon — "SplitPals alien"

The app icon is a friendly green alien (the SplitPals "pal") on the brand-purple
tile. It's generated from a single SVG definition so every appearance stays
consistent.

## Appearances (iOS 26)

The set follows the iOS 26 app-icon appearance model. `AppIcon.appiconset`
carries one 1024×1024 image per appearance:

| Appearance | File | Notes |
| --- | --- | --- |
| Default | `AppIcon-default.png` | Glossy purple tile with a Liquid-Glass sheen, vignette, and a soft drop shadow under the alien. Fully opaque (no alpha), as the App Store requires. |
| Dark | `AppIcon-dark.png` | Alien on a **transparent** background with a soft green halo — the system supplies the dark base gradient. |
| Tinted | `AppIcon-tinted.png` | Flat grey silhouette on transparent; iOS applies the user's tint colour based on luminance. |

The system rounds the corners and layers its own Liquid-Glass material on top,
so the source tiles are full-bleed squares.

## Regenerating

The PNGs and the `AppIcon-*.svg` sources are produced by
`generate-app-icon.mjs`:

```sh
npm i sharp            # one-off, only needed to run the generator
node design/generate-app-icon.mjs
```

Edit the artwork or colours in `generate-app-icon.mjs` (the `alien()` function
and the gradient `DEFS`) and re-run to refresh both the SVGs here and the PNGs
in `AppIcon.appiconset`. The same alien is used for the web PWA icons in the
`splitpals-online-beta` repo (`scripts/generate-icons.mjs`).
