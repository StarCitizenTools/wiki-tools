# tools

Helpers that ran against the wiki during a content migration and are kept for the next one. They are not part of `mise run test` or `mise run lint`. Each computes an edit plan locally so an agent can apply it through the MediaWiki MCP server and verify the saved page byte for byte; the scripts themselves never write to the wiki.

| Directory | Purpose |
|---|---|
| `entity-migration-audit/` | Measures the `Module:Item` to `Module:Entity` migration and writes a by-item-type matrix to `MIGRATION_STATUS.md`. See its README. |
| `production-state-migration/` | Per-page worklist and precomputed new sources for rewriting the vehicle production-state parameters into the `Added in version` model. |
| `vehicle-entity-migration/` | The `{{Vehicle}}` to `{{Entity}}` swap: the deterministic section-0 transform, the lead-pass spec, audit, and batch worklists. `lead-pass-spec.md` is the frozen per-page contract. |

Generators that produce wiki content on an ongoing basis live under `scripts/`, not here.
