# Module:Entity/Api

The single Apiunto I/O seam for the Entity system. Every piece of external game data the system renders passes through this module: callers supply an `EntityApiConfig` describing where and how to fetch, plus a UUID identifying the entity, and get back a decoded, unwrapped response table. Nothing outside this module calls `mw.ext.Apiunto` directly.

## Role in the pipeline

```
Kind.getApiConfigs / chain CHAIN_LINK.getApiConfigs
          ↓
   Module:Entity/Data  (probeKind / fetchChainExtras)
          ↓
   Api.fetchApi  ─── mw.ext.Apiunto.fetch
   Api.fetchAllApis       ↓
          ↓         mw.text.jsonDecode
   merged apiData          ↓
          ↓         unwrap responseDataPath
   facets / subtypes       ↓
                     data or {}
```

[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) is the only direct caller. It invokes `fetchApi` once per kind probe (in `probeKind`) and `fetchAllApis` over the supplemental config list (in `fetchChainExtras`). The merged `apiData` table then flows to every facet and subtype that renders the infobox — they read from that table but never touch `mw.ext.Apiunto` themselves.

## API

### `fetchApi(config, uuid) → data: table|nil, err: string|nil`

```lua
--- @param config table  API config: name, endpoint, params, responseDataPath (optional)
--- @param uuid   string The entity UUID to substitute into the endpoint
--- @return table|nil  data  Decoded, unwrapped response, or nil on failure
--- @return string|nil err   Error message if the fetch or decode failed
function p.fetchApi(config, uuid)
```

Performs a single fetch-decode-unwrap cycle:

1. Formats the endpoint string with `string.format(config.endpoint, uuid)` (line 17) — the config supplies a `%s` placeholder for the UUID.
2. `pcall`-guards `mw.ext.Apiunto.fetch(config.name, endpoint, config.params)`. A thrown error returns `nil, 'API fetch failed: …'` (lines 18–22).
3. `pcall`-guards `mw.text.jsonDecode(response)`. A decode error returns `nil, 'JSON decode failed: …'` (lines 24–27).
4. If `config.responseDataPath` is set, descends one level: `data = data[config.responseDataPath]` (lines 29–31). This strips the API envelope (e.g. `"data"`) so callers receive the payload directly.
5. Returns `data or {}` (line 33) — a path dereference that yields `nil` (e.g. the `responseDataPath` key is absent) becomes an empty table rather than `nil`. `fetchApi` itself never reports this as an error; the downstream consequence (it cannot raise `fetchAllApis`'s `hasError`) is covered in Gotchas.

### `fetchAllApis(configs, uuid) → apiData: table, hasError: boolean`

```lua
--- @param configs table[]  List of EntityApiConfig tables
--- @param uuid    string   The entity UUID
--- @return table   apiData   Flat-merged response data from all configs
--- @return boolean hasError  True if any individual fetch failed
function p.fetchAllApis(configs, uuid)
```

Iterates `configs` in order, calls `fetchApi` for each, and builds a single merged table (lines 43–58):

- If `fetchApi` returns an error, sets `hasError = true` and skips the merge for that config.
- Otherwise, copies every key from that config's response into `apiData` with `apiData[k] = v`.
- Returns `apiData, hasError`.

The merge is additive and last-writer-wins (see Gotchas).

## Data

### `EntityApiConfig` fields

`fetchApi` reads four fields from `config`:

| Field | Type | Required | Purpose |
|---|---|---|---|
| `name` | `string` | yes | Apiunto source name passed to `mw.ext.Apiunto.fetch` |
| `endpoint` | `string` | yes | URL template; `%s` is replaced with the UUID via `string.format` |
| `params` | `table` | yes\* | Query parameters forwarded to `mw.ext.Apiunto.fetch` |
| `responseDataPath` | `string` | no | If present, selects `response[responseDataPath]` as the payload |

\*`params` is passed straight through to `mw.ext.Apiunto.fetch` with no nil-guard in `fetchApi`. Supplying it is a caller convention (every kind's `getApiConfigs` sets it), not a runtime requirement the module enforces.

Kinds declare their `EntityApiConfig` tables in `getApiConfigs`. The first entry is the identity endpoint used by `probeKind`; subsequent entries become supplemental configs merged via `fetchAllApis`.

## Gotchas

**No schema validation — API drift fails silently.** The decoded response is trusted whole. If CIG renames or removes a field between game patches, `fetchApi` still returns a table, `hasError` stays `false`, and the facet or subtype that reads the renamed key renders blank without any error. `fetchApi` only fails on network/decode errors, not on shape mismatches. This is the system's main API-drift fragility: a field going missing is indistinguishable from a field being empty.

**`data or {}` masks a missing path.** If `config.responseDataPath` is set but the key does not exist in the decoded response, `data` becomes `nil` and the return is `{}`. The caller sees an empty table and `err = nil` — it looks like a successful empty response, not a structural mismatch.

**`fetchAllApis` flat-merge is last-writer-wins.** If two configs in the list both populate the same top-level key (e.g. both have a `"name"` field in their response), the later config overwrites the earlier one silently. Config ordering therefore matters and there is no collision warning.

**Forward: Phase-2 drift detection anchor.** This module is the planned hook point for the "API-field → module map" and any future `meta.deprecated_fields` handling. When CIG's API begins advertising deprecated fields in response metadata, the check belongs here — `fetchApi` sees the raw decoded envelope before `responseDataPath` strips it, making it the only place in the system where `meta` is still reachable.

## Tests

`Api` has no sibling `testcases.lua`. The module is a thin pure-I/O seam: both of its meaningful code paths call either `mw.ext.Apiunto.fetch` or `mw.text.jsonDecode`, neither of which is available in the ScribuntoUnit sandbox without a live API behind them. The `pcall` guards are the safety net — a thrown error from either extension call is caught and surfaced as an `err` return rather than a page render failure. Testing the merge logic or the `responseDataPath` unwrap in isolation would require mocking `mw.ext.Apiunto`, which Scribunto does not support. Integration coverage comes from the kind and facet tests that exercise the full pipeline on-wiki.

## Architecture

```
Entity/Api/
└── Api.lua    # fetchApi + fetchAllApis; no dependencies beyond strict + mw globals
```

`Api.lua` has no `require` calls beyond `require('strict')`. It reads only `mw.ext.Apiunto` and `mw.text`, both of which are globals provided by the Scribunto runtime. There are no load-order concerns and no internal state.
