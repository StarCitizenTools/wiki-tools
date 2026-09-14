# tests/

Local test layers. Run everything with `mise run test` (Lua manifest + unit suites, Go, gadget JS).

## Off-wiki ScribuntoUnit suites

The actual test cases live next to their modules at `pages/module/**/testcases.lua`
(the ScribuntoUnit convention; they are not deployed to the wiki). They are run headless in CI by the
[`mediawiki-scribuntounit`](https://github.com/StarCitizenTools/mediawiki-scribuntounit)
runner, consumed via mise (`[tools]` in `.mise.toml`, which provides the
`scribuntounit` command). Wiki-specific configuration — where modules live, which
render primitives to stub, and the `mw.ext.aggrid` / `BadgeLua` / `Yesno` /
`mw.ext.bucket` stand-ins — is declared in `scribuntounit.config.lua` at the
repo root.

```
mise run test:lua:unit            # all suites (auto-fetches the lualib first)
mise run test:lua:unit RangeBar   # filter to one module
```

`mw.ext.bucket` is a recorder: a query chain is captured as data in `mw.ext.bucket._chains` (select, join, where, limit, offset), `run()` returns rows installed with `_setRows(bucketName, rows)`, and `put()` appends to `_puts`. It is installed as the global `mw.ext.bucket` (what module code resolves) and is also require-able as `require('mw.ext.bucket')` (what suites use), both names resolving the same table. ScribuntoUnit has no per-test fixture hook, so suites that touch it call `_reset()` at the top of each test, or through a shared helper (`Store/testcases.lua`'s `withManifest`). Rows for a query with joins must be keyed by the qualified selector (`vehicle_stats.scm_speed`), which is how the real extension returns them.

The runner does NOT bundle the Scribunto lualib; it fetches it (pinned to
`scribunto.ref` in `scribuntounit.config.lua`, default `REL1_43`) into a
gitignored `.scribuntounit/` cache. `test:lua:unit` depends on `test:lua:fetch`
(`scribuntounit-fetch`), so the first run downloads it and later runs reuse the
cache; `scribuntounit-fetch --force` re-fetches. Requires a system `lua5.1`
(apt: `lua5.1` / brew: `lua@5.1`) plus `curl`/`wget`; do NOT use mise's `lua`
plugin (it builds from source and fails on CI).

## JSON manifest checks

`tests/manifest.lua` is a standalone validator for Module:Entity's JSON config
files (`types.json`, `classifications.json`, …) — shape and cross-reference
invariants. It uses only the vendored `tests/vendor/dkjson.lua`, no `mw` harness.

```
mise run test:lua:manifest
```

## Gadget JavaScript

`tests/js/` holds Node's built-in `node:test` suites for gadget JavaScript. They
`require()` the gadget source straight out of `pages/mediawiki/`, with no build
step and no dependencies, so a gadget file under test must stay CommonJS,
side-effect free, and free of the DOM and `mw` — `MediaWiki:Gadget-blame-text.js`
is split out from the gadget entry point for exactly that reason.

```
mise run test:js
```

Pass a name to filter, e.g. `node --test tests/js/blame-text.test.js`. Note that
pointing `node --test` at a bare directory exits 0 without running anything, so
the mise task globs the files.
