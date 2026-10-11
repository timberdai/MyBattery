# MyBattery application icon

`AppIcon.png` is the approved graphite-and-mint application icon master, with transparent corners. The application bundles `../bundle/AppIcon.icns`; the bilingual READMEs use `../../docs/app-icon.png`. The menu bar's live battery drawing remains in `Sources/MyBattery/BatteryGlyph.swift`.

Regenerate the ten standard macOS icon sizes and README preview on macOS:

```bash
./scripts/build-icon.sh
```

The design was generated and extracted with the built-in ImageGen tool on 2026-10-12. The original concept uses a graphite rounded square, a mint horizontal capsule battery with a short right terminal, and a negative-space lightning bolt slightly right of center.

Extraction prompt:

> Edit target: attached MyBattery logo concept presentation. Extract ONLY the large left-hand application icon as a standalone production asset. Preserve exactly the approved large icon design: charcoal graphite rounded-square background with subtle depth, mint green horizontal rounded capsule battery and short rounded terminal on right, dark negative-space lightning slightly right of center. Preserve its shape, color, proportions and lightning location, no redesign. Remove the entire off-white presentation background, all text, all right-hand smaller examples, and the exterior drop shadow. Output a square high-resolution PNG with true transparent corners outside the rounded-square icon; icon bounds occupy the square tightly with a tiny equal margin on four sides. Crisp clean edges, no text, no extra elements. The dark rounded-square BACKGROUND OF THE ICON stays opaque. Transparency is only outside it. This will be used for macOS AppIcon.icns.
