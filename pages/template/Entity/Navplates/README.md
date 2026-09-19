# Template:Entity/Navplates

Renders the browse row at the foot of an entity page: a bar linking out to the manufacturer's catalogue and to the type hub, each showing how much is on the other side. Place it last on the page, below the body content.

## Usage

No parameters, on a page where `{{Entity}}` has already been invoked:

```wikitext
{{Entity}}

{{Entity/Navplates}}
```

On a page with no `{{Entity}}` call, name the entity:

```wikitext
{{Entity/Navplates|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the entity whose manufacturer and type the row points at. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |
| `manufacturer` | Manufacturer | string | No | (from the API record, else the page's stored row) | Names the manufacturer directly, as a code or a full name. Use it where the API names none and the page carries no stored value. | `Associated Sciences & Development` |

## Behavior

- Each cell appears only when its destination resolves, so a page can show two cells, one, or no bar at all.
- The manufacturer cell prefers `manufacturer=`, then the API record, then the manufacturer stored on the page by a previous `{{Entity}}` parse. The stored value is consulted for `UNKN` as well as for a missing one, because the API returns `UNKN` wherever the real maker is unrecorded and it would otherwise hide an editorial `manufacturer=`.
- The type cell links the hub for the entity's type, falling back to the browse categories its type chain contributed and then to the type stored on the page. `Ships`, `Vehicles` and `Spacecraft` have no index to link, so a spacecraft reaches a role hub such as `Medium ships` or shows no type cell.
- Both links land on the destination's `#list` anchor, so the reader arrives at the index rather than the lead.
- The count beside each cell is omitted rather than shown as zero when it cannot be established. A type hub reached through a browse category carries no count at all, because the pages in that category are a curated set that no single type selects.
- Counts are baked into the parser cache, which expires after three days, so a count can trail the wiki by that much.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data and supplies the uuid this template falls back to.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for set pieces and variants.
- [Module:Entity/Navplates](https://starcitizen.tools/Module:Entity/Navplates), the implementation.
