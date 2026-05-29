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

## Wiki URL paths

Star Citizen Wiki runs with `$wgArticlePath = "/$1"` — articles live at the **root**, not under `/wiki/`. When you build URLs in wikitext, Lua, or CSS, use:

- `/Special:FilePath/<File>` — canonical redirect to a file's CDN URL (e.g. for `mask-image: url(...)` and similar). `/wiki/Special:FilePath/…` 404s.
- `/<Page name>` — internal links you compose manually (most of the time prefer `[[Page name]]` and let MediaWiki build the URL).

The wiki's CDN host (`media.starcitizen.tools`) is the eventual target for file URLs after the `Special:FilePath` redirect chain. Don't hard-code the CDN host; the redirect path is what's stable.

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

To verify behavior that depends on wiki runtime — rendered output, parser behavior, extension APIs, cross-`#invoke` state, visual QA, automated UI flows — deploy a scratch module to `Module:Sandbox/<Username>/<TestName>` and a wikitext harness to `User:<Username>/sandbox/<test-name>`. Delete both pages once the question is answered.

- When creating a module page, always pass `contentModel: Scribunto` — the default `wikitext` silently produces "No such module" errors.
- **Use Playwright CLI (the `playwright-cli` skill) for any visual, CSS, or interaction check** — anything to do with how a thing *looks* or *behaves*. Parsing the page HTML (via `action=parse` or `get-page`) only proves the markup/classes are emitted; it cannot tell you whether styles loaded, an icon is the right size, hover states fire, or a `<details>` actually toggles. Those regressions are invisible to HTML inspection (e.g. a card that emits the right classes but renders unstyled because its TemplateStyles weren't injected). Drive a real browser: `playwright-cli open <url>`, then assert on **computed styles** and live interactions, e.g. `playwright-cli eval "() => getComputedStyle(document.querySelector('.t-collapsible-card__icon')).width"` and `playwright-cli click` to toggle. Reserve HTML-fetch checks for data/structure assertions (row counts, presence of a value), not for look-and-feel.
- Remember the live MediaWiki **parser cache**: after deploying a module change, `?action=purge` the test page (POST) before re-inspecting, or you will read a stale render.

## Formatting

Linters in `.mise.toml` enforce style. Run `mise run lint` to check, `mise run fix` to auto-fix.

## Project skills

Project-scoped agent skills live under `.agents/skills/<name>/SKILL.md`. They encode workflows specific to wiki-tools (e.g., deploying to the wiki, converting README parameter tables to TemplateData). Always check `.agents/skills/` for an applicable skill before improvising a workflow that overlaps with one of those concerns. Personal skills under `~/.claude/skills/` are not the right place for this project's conventions.
