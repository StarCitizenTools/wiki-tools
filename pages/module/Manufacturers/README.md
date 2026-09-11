# Module:Manufacturers

Registry of Star Citizen manufacturers: looks up a manufacturer by code (e.g. `AEGS`) or full name (e.g. `Aegis Dynamics`) and returns a canonical record, so downstream code relies on one form regardless of what an editor typed.

Required by [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base) and [Module:Company](https://starcitizen.tools/Module:Company); not invoked from templates.

## For module editors

### API

`p.resolve(codeOrName)` returns `{ code, name, short, page }`, or `nil` when nothing matches. `short` falls back to `name` when no short form is defined; `page` falls back to `name` when the page title matches. Lookup by code is an O(1) hash access; lookup by name is an O(n) scan of the data.

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

`resolve` reads [Module:Manufacturers/data.json](https://starcitizen.tools/Module:Manufacturers/data.json) via `mw.loadJsonData`, whose returned table is a read-only proxy: direct key access (`data[code]`) and `pairs()` (used for the name scan) see the real entries, but the Lua length operator (`#`) and `next()` do not.
