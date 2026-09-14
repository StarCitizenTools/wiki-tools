# Template:Entity/Ports

Renders an entity's port loadout as a vertical stack of collapsible category cards (Weapons, Manned Turrets, Coolers, Quantum Drives, Life Support, and so on). Place it as body content further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID:

```wikitext
{{Entity/Ports|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Ports ==
{{Entity/Ports}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- Renders for both items and vehicles, but not identically: vehicle port trees go through an extra narrowing pass that drops child ports whose type isn't on that category's allowlist (a turret's L-tree keeps its mounted gun but drops cockpit panels and displays). Item port trees skip that pass, so the same category can show more children on an item page than on the equivalent vehicle page.
- Cards render one per category, sorted by an ordering defined in `categories.json` (Weapons before Turrets before Coolers, and so on); primary categories open by default. A category CIG adds before the list is synced still renders as its own card, rather than being dropped.
- Sibling ports with an identical loadout collapse into one aggregated row with a count prefix (`04×`, `13×`); mixed loadouts naturally produce multiple rows. M4A-style attachment ports (BAR, MEC, POW, VEN) stay distinct because they accept different sub-types even though the slots look interchangeable.
- Size pills show the equipped item's size when something's installed, falling back to the port's accepted range when empty (e.g. `S1–5` for a flex fuel mount).
- Parent ports whose category opts into expansion render an indented tree of their children below the row: turrets expose their mounted gun, missile racks their missiles, quantum drives their jump drive.
- Engine, cockpit, and animation hardpoints (Controllers, Crew Stations, Doors & Hatches, Thrusters, Fuel, and so on) collapse into a single closed-by-default "Other" card at the bottom, sub-grouped by their original category label so the reader can still tell what's where. If every top-level port on the page lands in a collapsed category, only that "Other" card renders; there is no separate empty state, since it can still be expanded.
- Hardware-locked ports show a diagonal stripe on their size pill.
- On a carrier ship, a docking port shows the docked vehicle's own name and size rather than the docking-tube hardware occupying that port; the docked vehicle's own internal ports (fuel, relay, screen mounts) aren't shown, since that vehicle has its own page for its loadout. Docking ports are routed to the "Docked Vehicles" category, which sorts first, so they always appear at the top of the stack.
- An upstream fetch failure shows the muted line "Port data unavailable."; an entity with no ports at all shows "No ports." instead.
- There is nothing here for an editor to curate beyond `uuid`.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), sibling renderer for where an entity can be acquired.
- [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy), sibling renderer for the vehicles that use an item.
- [Module:Entity/Ports](https://starcitizen.tools/Module:Entity/Ports), the implementation.
