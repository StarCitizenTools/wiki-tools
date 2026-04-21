# AGENTS.md

Guidance for LLM agents working in this repository.

## Project Overview

Wiki pages, modules, and automation for [Star Citizen Wiki](https://starcitizen.tools). The `pages/` directory mirrors the wiki's namespace. Lua modules run in Scribunto (Lua 5.1) with the `mw` global.

### Filesystem mirror

- Each wiki namespace is a subdirectory under `pages/` (e.g., `module/`, `template/`).
- A page that has subpages lives inside its own directory next to those subpages. Examples:
  - `Module:InfoboxLua` → `pages/module/InfoboxLua/InfoboxLua.lua`
  - `Module:Entity` → `pages/module/Entity/Entity.lua`, with `Module:Entity/Base` at `pages/module/Entity/Base.lua`
  - `Template:Entity` → `pages/template/Entity/Entity.wikitext`, with `Template:Entity/Description` at `pages/template/Entity/Description.wikitext`
- File extensions track content model: `.lua` for Scribunto modules, `.wikitext` for template/wikitext pages, `.css` for TemplateStyles.

## Architecture Patterns

- **Rendering components** (InfoboxLua and children): validate input with `Util.validateAndConstruct(rawData, schema)` against a schema from `Types.lua`, then build and return `mw.html` nodes. Each component exposes `p.getHtml(data)`.
- **Entity chain**: type modules are linked via `p.parent` (e.g., `Food → Item → Base`) and each contributes lifecycle hooks — `getSections`, `getStructuredData`, `getApiConfigs`, `getShortDescription`, `getExternalSiteItems`. `Module:Entity` walks the chain to render the infobox and own page metadata (SMW, SHORTDESC, categories); sibling renderers on the same page consume `Module:Entity/Data` for shared fetch + type resolution.

## Code Conventions

- Lua 5.1 with `require('strict')` at the top of every module.
- LuaCATS annotations (`--- @class`, `--- @field`, `--- @param`, `--- @return`).
- Module imports use MediaWiki paths: `require('Module:InfoboxLua/Util')`.
- CSS class prefix follows the owning component (e.g., `t-infobox-` for InfoboxLua).
- CSS uses design tokens from the Citizen skin (`--space-md`, `--color-surface-1`, etc.).

## Scribunto API

Modules run in [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual) and have access to the `mw` global. LuaCATS type stubs for the full API live in `types/mw/`, sourced from the [REL1_43 branch](https://github.com/wikimedia/mediawiki-extensions-Scribunto/tree/REL1_43/includes/Engines/LuaCommon/lualib).

### HTML tags in wikitext

MediaWiki's parser sanitizes unknown HTML tags by escaping them as literal text rather than rendering them. `mw.html` output is subject to the same allowlist. The canonical set is defined in [Sanitizer.php's `getRecognizedTagData()`](https://github.com/wikimedia/mediawiki/blob/REL1_43/includes/parser/Sanitizer.php) for MediaWiki 1.43.

Key gotchas:

- HTML5 structural tags — `header`, `footer`, `figure`, `figcaption`, `section`, `article`, `aside`, `nav`, `main`, `hgroup` — are **not** allowed. Use `<div>` or `<p>` with a role class instead.
- `<details>` and `<summary>` work on this wiki because `Extension:Details` provides them; they are not in MediaWiki core.

## Testing

Unit tests use `Module:ScribuntoUnit` and live alongside the module they test (e.g., `Util/testcases.lua` → `Module:InfoboxLua/Util/testcases`).

- Tests run on the wiki, not locally — deploy first. The documentation template surfaces results on the module's wiki page.
- Only test modules with real logic (validation, data transformation). Skip rendering components that return `mw.html` or strip markers.
- Prefix test functions with `test`; ScribuntoUnit ignores everything else.

### Browser Testing

To verify behavior that depends on wiki runtime — rendered output, parser behavior, extension APIs, cross-`#invoke` state, visual QA, automated UI flows — deploy a scratch module to `Module:Sandbox/<Username>/<TestName>` and a wikitext harness to `User:<Username>/sandbox/<test-name>`. Inspect via HTML fetch, browser, or an automation tool (Playwright, Chrome DevTools MCP). Delete both pages once the question is answered.

- When creating a module page, always pass `contentModel: Scribunto` — the default `wikitext` silently produces "No such module" errors.

## Formatting

Linters in `.mise.toml` enforce style. Run `mise run lint` to check, `mise run fix` to auto-fix.
