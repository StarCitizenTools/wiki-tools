# tests/

Local test layers. Run everything with `mise run test` (manifest + unit).

## Off-wiki ScribuntoUnit suites

The actual test cases live next to their modules at `pages/module/**/testcases.lua`
(the on-wiki ScribuntoUnit convention). They are run headless in CI by the
[`mediawiki-scribuntounit`](https://github.com/StarCitizenTools/mediawiki-scribuntounit)
runner, consumed via mise (`[tools]` in `.mise.toml`, which provides the
`scribuntounit` command). Wiki-specific configuration — where modules live, which
render primitives to stub, and the `mw.ext.aggrid` / `BadgeLua` / `Yesno`
stand-ins — is declared in `scribuntounit.config.lua` at the repo root.

```
mise run test:lua:unit            # all suites (auto-fetches the lualib first)
mise run test:lua:unit RangeBar   # filter to one module
```

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

## Future test types

Other test types (e.g. vitest for JS gadgets) get their own subdir here and their
own mise task.
