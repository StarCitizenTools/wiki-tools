# Module:ReputationStyler

Renders a reputation rank as its rank icon followed by the rank name, for the reputation scopes listed in its `config.json`. A rank in a scope it does not list comes out as plain text.

No template invokes it. Required by [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission), which styles the minimum and maximum standing in a mission's Reputation section with it.

## For module editors

### API

- `p.style(rank, scope)`: returns the rank as an icon and text pair, built with [Module:IconText](https://starcitizen.tools/Module:IconText) and carrying this module's `<templatestyles>` tag. Returns `"Unspecified"` when `rank` is missing or empty, and `rank` unchanged when `scope` is missing or the pair is not in `config.json`.
- `p.getIcon(rank, scope)`: the icon file name for a rank, or `nil`.
- `p.main(frame)`: wikitext entry point; reads `rank` and `scope` via [Module:Arguments](https://starcitizen.tools/Module:Arguments) and calls `style`.

### Extending

`config.json` has two maps. `icon_sets` names each set of rank icons (`faction`, `security`) and maps a rank key (`r0`, `r1`, …) to a file. `mapping` is keyed by reputation scope and gives each scope an `icon_set` plus a `ranks` table from the in-game rank name to that rank key. Supporting a new scope is a `mapping` entry; a new icon style is an `icon_sets` entry.

### Gotchas

- The `scope` that `Module:Entity/Mission` passes has already been through its own label table (`SCOPE`), so a scope it renames, such as `BountyHunter_BountyHuntersGuild` to `Bounty Hunter`, must be keyed by the renamed label in `mapping`, or its ranks stay plain text.
- Rank names are matched exactly, including case and punctuation (`Jr. Security Contractor`).

### Styles

`.t-reputation-styler__container` is the wrapper. Inside an infobox item (`.t-infobox-item-content`) the stylesheet reverses the icon and text so the icon sits after the name.
