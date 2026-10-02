# Module:Manufacturers

Registry of Star Citizen manufacturers: looks up a manufacturer by exact code (e.g. `AEGS`) or exact full name (e.g. `Aegis Dynamics`) and returns a canonical record, so downstream code relies on one form for a value that could arrive as either.

Required by [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base) and [Module:Company](https://starcitizen.tools/Module:Company); not invoked from templates.

## For module editors

### API

`p.resolve(codeOrName)` returns `{ code, name, short, page }`, or `nil` when nothing matches. Link via `page`, display via `name` or `short`, store `code`: `page` is not always `name` (ArcCorp's `name` is `'ArcCorp'`, its `page` is `'ArcCorp (company)'`), so a caller that links `[[<record.name>]]` instead of `[[<record.page>|<record.name>]]` can build a red link to the wrong title. `short` falls back to `name` when no short form is defined; `page` falls back to `name` when no override is defined. Lookup by code is an O(1) hash access; lookup by name is an O(n) scan of the data. Both are exact-match, case-sensitive comparisons; there is no trimming or normalisation.

```lua
local manufacturers = require( 'Module:Manufacturers' )
manufacturers.resolve( 'AEGS' )
--> { code = 'AEGS', name = 'Aegis Dynamics', short = 'Aegis', page = 'Aegis Dynamics' }
```

Entries live in [Module:Manufacturers/data.json](https://starcitizen.tools/Module:Manufacturers/data.json), keyed by code:

```json
{
	"AEGS": { "name": "Aegis Dynamics", "short": "Aegis" },
	"ARCC": { "name": "ArcCorp", "page": "ArcCorp (company)" }
}
```

`name` is required; `short` and `page` are optional and default to `name`. Add a manufacturer by adding a new key with the minimum required field.

### Gotchas

`UNKN` and `NONE` are records, not companies. `UNKN` (page `Unknown manufacturer`) is the API's code for a maker it has not recorded; `NONE` (page `No manufacturer`) is set by editors and the item importer for items no company makes. Both resolve so a page links a catalogue and files in its category. [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base) still drops `NONE` when it arrives from the API, so only an explicit `|manufacturer = NONE` reaches this entry.

`resolve` reads [Module:Manufacturers/data.json](https://starcitizen.tools/Module:Manufacturers/data.json) via `mw.loadJsonData`, whose returned table is a read-only proxy: direct key access (`data[code]`) and `pairs()` (used for the name scan) see the real entries, but the Lua length operator (`#`) and `next()` do not.
