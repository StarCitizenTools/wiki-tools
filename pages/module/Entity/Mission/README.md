# Module:Entity/Mission

Mission kind: contracts backed by the game-data `/api/missions` endpoint. One flat kind with no leaves, covering every contract type the game offers, from bounty and mercenary work to Wikelo's barter collections.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the page's uuid resolves to a mission record. The pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### API

- `p.name = 'Mission'`: canonical kind name, exposed as `Data.get(args).kind`.
- `p.matches(apiData) → boolean`: true for any record carrying a `mission_type`. No other endpoint emits that key, so the probe needs nothing more.
- `p.getApiConfigs() → EntityApiConfig[]`: the `missions/%s` identity endpoint.
- `p.getTypeInfo(ctx)`: the display type and its browse category, both derived from the raw `mission_type` rather than enumerated. Only the Wikelo buckets and one mis-tagged record are remapped, in `TYPE_LABELS`.
- `p.getSections(ctx)`: the infobox. A General section always, then Payout, Reputation, Requirements and Location, each gated on having a value.
- `resolveFaction(apiData)` (local): the faction the infobox row, the stored `Faction` property and the short description all use, so they cannot disagree.
- `p.getStructuredData(ctx)`: the `mission` Bucket row. `orders` and `rewards` come from [Module:Entity/Orders/Lines](https://starcitizen.tools/Module:Entity/Orders/Lines) and [Module:Entity/Rewards/Lines](https://starcitizen.tools/Module:Entity/Rewards/Lines), the same formatters the visible tables use, so a stored line and a rendered row never disagree.
- `p.getShortDescription(ctx)`: `"<Faction> <type> contract"`, degrading to `"<Type> contract"` and then to nil as the record gets thinner.

### Extending

Contract types are **not** enumerated. `typeLabel` passes an unrecognised `mission_type` through unchanged and `typeCategory` derives `<Type> contracts` from it, so a type CIG adds in a patch renders under its own name with no edit here. Add to `TYPE_LABELS` only when the API string is not what a reader should see. Two consequences worth knowing: the derived category may not exist yet as a page, and a hyphenated type (`Hauling - Planetary`) derives an awkward category name, which is the case to add an override for.

Three sibling renderers read this kind's record and store nothing: [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders), [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards) and [Module:Entity/Combat](https://starcitizen.tools/Module:Entity/Combat).

### Gotchas

- `typeCategory` lowercases everything after the first letter, matching the names the retired `{{Contract}}` template generated through `{{Fixcaps}}`. That is what routes `Bounty Hunter` to the existing `Category:Bounty hunter contracts` instead of creating a near-miss duplicate; changing the casing orphans every page already filed there.
- Around 100 records in the corpus carry neither `faction.name` nor `mission_giver`, so every faction read needs a fallback. The infobox Faction row is simply absent on those.
- `mission_giver` is preferred over `faction.name`, not the other way round: it names the specific contractor a reader can look up (MT Protection Services, BlacJac Security, Miles Eckhart) where `faction.name` gives only the parent corporation (microTech, ArcCorp, Eckhart Security). `resolveFaction` falls back to `faction.name` only when the giver is an unresolved internal token, matched on shape (`_`, `~`, a `BountyDepartment` suffix, or `N/A`) rather than by name, since the same token resolves differently per record. `XenoThreat` is deliberately not matched: it is a real faction name that happens to be unspaced, and a CamelCase rule would also have eaten microTech, ArcCorp and BlacJac.
- A contract can award either MG Scrip or Council Scrip; the payout row is labelled from the reward the record actually carries, not from a fixed string.
- `not_for_release` marks a contract unavailable, but `|available=` overrides it in both directions: several pages document a contract the API still flags as unreleased.
- Prerequisite titles go through `fixTitle`, which strips brackets and turns a pipe into a hyphen. Mission titles contain templating placeholders (`Claim #[ClaimNumber]: [Ship] Salvage Rights`) that would otherwise emit a broken link.
