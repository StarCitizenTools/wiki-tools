# Module:Jump points

Renders the jump point table on a star system page: one row per jump gate in the system, with its direction, size, and destination (system and gate). Reached through [Template:Jump points](https://starcitizen.tools/Template:Jump_points), which wraps `{{#invoke:Jump points|main}}` with no arguments (the system name defaults to the current page title, minus a trailing " system").

## For module editors

### API

- `JumpPoints.main(frame)`: reads the system's jump points from [Module:Starmap](https://starcitizen.tools/Module:Starmap) (off-repo, not mirrored) and returns the rendered wikitable, or an i18n error message when the system has no data or no jump points.
- `exists(page)`: whether `page` exists as a wiki page (`mw.title.new(page).exists`), used to flag a destination gate with no page yet via `Module:Jump points/config.json`'s `missing_jumppoint_category`. It takes a bare title: `mw.title.new` rejects a title containing brackets, so passing `[[Title]]` marks every system as missing.

### Gotchas

- This file is bundled output from [ari-party/sct-module-jump-points](https://github.com/ari-party/sct-module-jump-points) via [scribunto-bundler](https://github.com/ari-party/scribunto-bundler), inlining that project's own `Module:Translate` wrapper and a small string-cleaning helper as anonymous registered chunks; a future logic change belongs upstream and should arrive here as a re-bundle, not a hand-edit, except where a repository-specific fix can't wait for that.
- `Module:Jump points/config.json` and `Module:Jump points/i18n.json` are off-repo and stay live; this module stores and reads nothing, so it carries no [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) dependency.
- No `testcases.lua` ships with this mirror: the module is vendored, generated output, not something edited here function-by-function.
