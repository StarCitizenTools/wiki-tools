# AGENTS.md

This file provides guidance to LLM agents when working with code in this repository.

## Project Overview

Wiki pages, modules, and automation for [Star Citizen Wiki](https://starcitizen.tools). The `pages/` directory mirrors the wiki's namespace structure (e.g., `pages/module/InfoboxLua/InfoboxLua.lua` → `Module:InfoboxLua`). Lua modules run in Scribunto (Lua 5.1) with the `mw` global API.

## Architecture Pattern

Components follow a consistent pattern: validate input data with `Util.validateAndConstruct(rawData, schema)` against a schema from `Types.lua`, then build and return `mw.html` nodes. Each component exposes `p.getHtml(data)`.

## Code Conventions

- Lua 5.1 with `require('strict')` at the top of each module
- LuaCATS annotations (`--- @class`, `--- @field`, `--- @param`, `--- @return`)
- Module imports use MediaWiki paths: `require('Module:InfoboxLua/Util')`
- CSS class prefix: `t-infobox-` for InfoboxLua components
- CSS uses design tokens from the Citizen skin (`--space-md`, `--color-surface-1`, etc.)

## Scribunto API

Modules run in [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual) and have access to the `mw` global. LuaCATS type stubs for the full API are in `types/mw/`, sourced from the [REL1_43 branch](https://github.com/wikimedia/mediawiki-extensions-Scribunto/tree/REL1_43/includes/Engines/LuaCommon/lualib).

## Testing

Unit tests use `Module:ScribuntoUnit`. Test files live alongside the module they test as `<Name>/testcases.lua` (e.g., `Util/testcases.lua` → `Module:InfoboxLua/Util/testcases`).

- Tests run on the wiki, not locally — deploy first. Results appear automatically on the module's wiki page via the documentation template.
- Only test modules with real logic (validation, data transformation). Don't test rendering components that return `mw.html` or strip markers.
- Prefix test functions with `test`. Other functions are ignored by ScribuntoUnit.

## Formatting

Enforced by linters configured in `.mise.toml`. Run `mise run lint` to check, `mise run fix` to fix.
