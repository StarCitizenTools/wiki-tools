# Module:Jump points

Renders the jump point table on a star system page: one row per jump gate in the system, with its direction, size, and destination (system and gate). Reached through [Template:Jump points](https://starcitizen.tools/Template:Jump_points), which wraps `{{#invoke:Jump points|main}}` with no arguments (the system name defaults to the current page title, minus a trailing " system").

## For module editors

### API

- `JumpPoints.main(frame)`: reads the system's jump points from [Module:Starmap](https://starcitizen.tools/Module:Starmap) (off-repo, not mirrored) and returns the rendered wikitable, or an i18n error message when the system has no data or no jump points.
- Each gate links to `<Entry> - <Destination> jump point`, the title every gate page carries, showing the name without the suffix. Each side of the starmap designation goes through `systemShortName` from [Module:Entity/Location/Starmap](https://starcitizen.tools/Module:Entity/Location/Starmap), which strips an alias parenthetical (`Kyuk'ya (Indra)`) and the Vanduul catalogue form (`VS-9 "Vulture"`); neither is in a page title, so the link must not use the designation as is.

### Gotchas

- The wiki-tools repository is the module's source. The file keeps the layout [scribunto-bundler](https://github.com/ari-party/scribunto-bundler) gave it when it came from [ari-party/sct-module-jump-points](https://github.com/ari-party/sct-module-jump-points): a `Module:Translate` wrapper and a small string-cleaning helper inlined as anonymous registered chunks. Edit the chunks in place; re-bundling the upstream project over the file would drop the gate-title fix.
- `Module:Jump points/config.json` and `Module:Jump points/i18n.json` are off-repo and stay live; this module stores and reads nothing, so it carries no [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery) dependency.
- There is no `testcases.lua`: the module requires [Module:Starmap](https://starcitizen.tools/Module:Starmap), `Module:Common` and `Module:Translate`, none mirrored here, so the runner would need a stub for each.
