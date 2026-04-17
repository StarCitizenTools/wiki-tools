# Module:Manufacturers

Registry of Star Citizen manufacturers. Looks up a manufacturer by code (e.g. `AEGS`) or full name (e.g. `Aegis Dynamics`) and returns a canonical record with the code, full name, short name, and wiki page.

Use this whenever a template or module accepts a manufacturer value in wikitext — it normalizes user input so downstream code can rely on a single canonical form regardless of what the editor typed.

## Usage

```lua
local manufacturers = require( 'Module:Manufacturers' )

local record = manufacturers.resolve( 'AEGS' )
-- { code = 'AEGS', name = 'Aegis Dynamics', short = 'Aegis', page = 'Aegis Dynamics' }

local byName = manufacturers.resolve( 'Aegis Dynamics' )
-- same record as above

local unknown = manufacturers.resolve( 'Not a manufacturer' )
-- nil
```

Callers pick the form they need:

- Wikilink: `[[<record.page>|<record.name>]]`
- Short-form display: `<record.short>`
- Stored structured data: `<record.code>`

## API

### `p.resolve( codeOrName )`

Looks up a manufacturer by code or name.

| Parameter | Type | Description |
|---|---|---|
| `codeOrName` | `string` or `nil` | Manufacturer code (e.g. `AEGS`) or full name (e.g. `Aegis Dynamics`). |

Returns a record table, or `nil` if no match:

| Field | Type | Description |
|---|---|---|
| `code` | `string` | Canonical manufacturer code. |
| `name` | `string` | Full display name. |
| `short` | `string` | Short display name. Falls back to `name` when no short form is defined. |
| `page` | `string` | Wiki page title for `[[links]]`. Falls back to `name` when the page title matches. |

Lookup by code is an O(1) hash access; lookup by name is an O(n) scan.

## Data

Entries live in [Module:Manufacturers/data.json](https://starcitizen.tools/Module:Manufacturers/data.json). Each entry is keyed by the manufacturer code:

```json
{
    "AEGS": { "name": "Aegis Dynamics", "short": "Aegis" },
    "MISC": { "name": "Musashi Industrial and Starflight Concern", "short": "MISC" }
}
```

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Full display name. |
| `short` | No | Short display name. Defaults to `name`. |
| `page` | No | Wiki page title when it differs from `name`. Defaults to `name`. |

Add a new manufacturer by adding a new key (the code) with the minimum required fields.

## Architecture

```
Manufacturers/
├── Manufacturers.lua    # Lookup function
└── data.json            # Manufacturer registry
```
