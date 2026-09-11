# Module:Entity/Api

The sole Apiunto I/O seam for the Entity system: takes an `EntityApiConfig` and a uuid, returns a decoded, unwrapped response table. Nothing outside this module calls `mw.ext.Apiunto` directly.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.fetchApi(config, uuid) → data: table, err: string|nil`: one fetch-decode-unwrap cycle. Formats `config.endpoint` with `uuid` via `string.format`, calls `mw.ext.Apiunto.fetch(config.name, endpoint, config.params)`, JSON-decodes the response, and descends into `config.responseDataPath` if set. `config` is an `EntityApiConfig` (`name`, `endpoint`, `params`, `responseDataPath`; see [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types)). Returns `{}`, never `nil`, when the payload is missing.
- `p.fetchAllApis(configs, uuid) → apiData: table, hasError: boolean`: calls `fetchApi` over each config in order and flat-merges every returned key into one table; `hasError` is true if any individual fetch failed.

### Gotchas

- No schema validation: a renamed or removed API field is invisible to this module. `fetchApi` still returns a table, `hasError` stays false, and the consuming facet just renders blank.
- `data or {}` masks a missing path: a `responseDataPath` key absent from the response becomes an empty table, not an error, so it looks identical to a genuinely empty payload.
- `fetchAllApis`'s merge is last-writer-wins: two configs producing the same top-level key collide silently, so config order matters.
- Apiunto caches by requested URL, so a record always lands on the same cache key regardless of which endpoint or template triggered the fetch.
- The `search/<uuid>` endpoint is never used as a fetch path here: its key can't coincide with a typed endpoint's, and upstream it is rate-limited (60/min) and marked uncacheable.
- `params` is appended to the endpoint as `?query`; an endpoint that already carries its own `?filter[...]` must carry `locale` inline in the endpoint string, not via `params`, or the second `?` corrupts the query.
- The configured Apiunto source keeps redirect-following off, so a foreign-kind uuid that would redirect (a vehicle uuid fetched on the items endpoint) fails the fetch instead of getting cached under the wrong key.
