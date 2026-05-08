# wiki-tools

Wiki pages, modules, and automation for [Star Citizen Wiki](https://starcitizen.tools).

## Repository layout

| Path | Contents |
|---|---|
| `pages/` | 1:1 mirror of the wiki, organized by namespace. See [`AGENTS.md`](AGENTS.md) for the path-to-title rules. |
| `types/mw/` | LuaCATS stubs for the [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) `mw` API, mirrored from upstream `REL1_43`. |
| `.agents/skills/` | Agent skills that automate wiki workflows — deploy, sync, doc conversion. |
| `AGENTS.md` | Architecture patterns, code conventions, and Scribunto gotchas. Start here if you're contributing modules. |

## Pages

Each module's subpages and styles live alongside the entry point listed below.

### Entity system

Renders item and vehicle pages. Type modules link via `p.parent` (e.g., `Food → Item → Base`); `Module:Entity` walks the chain to render the infobox and emit page metadata.

| Page | Description |
|---|---|
| [Module:Entity](pages/module/Entity) | Chain root — infobox plus structured data (SMW, `SHORTDESC`, categories). |
| [Module:Entity/Availability](pages/module/Entity/Availability) | Where-to-buy availability block. |
| [Module:Entity/Description](pages/module/Entity/Description) | Long-form description block. |
| [Module:Entity/Related](pages/module/Entity/Related) | Related items and set-piece cards. |
| [Module:Entity/Ports](pages/module/Entity/Ports) | Item ports and hardpoints. |
| [Module:Entity/Item](pages/module/Entity/Item) | Item type — `Drink`, `Food`, `WeaponPersonal` variants. |
| [Module:Entity/Blueprints](pages/module/Entity/Blueprints) | Blueprint aspects and dismantle returns. |
| [Template:Entity](pages/template/Entity) | Wikitext wrappers, one per renderer. |

### Layout & rendering

Reusable building blocks for modules and wikitext.

| Page | Description |
|---|---|
| [Module:InfoboxLua](pages/module/InfoboxLua) | Data-driven infobox: collapsible sections, tabs, multi-column layouts. |
| [Module:CollapsibleCard](pages/module/CollapsibleCard) | Card with a summary line and an expandable body. Falls back to static when no body is given. |
| [Module:TableLua](pages/module/TableLua) | Codex-style sortable table — pass `props`, get rendered HTML. |
| [Module:Details](pages/module/Details) | Wrapper for `<details>`/`<summary>` that survives the sanitizer. |
| [Module:BadgeLua](pages/module/BadgeLua) | Inline pill-shaped label with semantic variants (`error`/`success`/`warning`) and an icon slot. |
| [Template:Badge](pages/template/Badge) | Wikitext wrapper around `Module:BadgeLua`. Accepts `{{Badge\|text\|bg=…\|color=…\|variant=…}}`. |

### Data & utilities

| Page | Description |
|---|---|
| [Module:Manufacturers](pages/module/Manufacturers) | Manufacturer registry — resolves a code or name to a canonical record. |

### Testing

| Page | Description |
|---|---|
| [Module:ScribuntoUnit](pages/module/ScribuntoUnit) | Unit testing framework. Tests run on the wiki and surface results on the module's doc page. |

## Development

Install [mise](https://mise.jdx.dev), then:

```sh
mise install        # Install stylua, gale-lint, lefthook
lefthook install    # Register pre-commit hooks
mise run lint       # Check formatting
mise run fix        # Auto-fix formatting
```

Pre-commit hooks (see [`lefthook.yml`](lefthook.yml)) run the same checks as `mise run lint`, so `git commit` blocks on style violations.

For everything else — code conventions, the `mw.html` allowlist, browser testing on a sandbox wiki — see [`AGENTS.md`](AGENTS.md).

## Agent skills

Project skills under `.agents/skills/`. Describe the task in plain English; your agent picks the matching skill.

| Skill | Use it for |
|---|---|
| [`deploy-to-wiki`](.agents/skills/deploy-to-wiki/SKILL.md) | Push a local module or template to the wiki, including its `/doc` page. |
| [`sync-from-wiki`](.agents/skills/sync-from-wiki/SKILL.md) | Pull recent upstream wiki edits into the local mirror — the inverse of deploy. |
| [`doc-page-from-readme`](.agents/skills/doc-page-from-readme/SKILL.md) | Convert a `README.md` to the wikitext used for `/doc` subpages. Called by `deploy-to-wiki`. |
| [`templatedata-from-readme`](.agents/skills/templatedata-from-readme/SKILL.md) | Convert a Markdown Parameters table to a `<templatedata>` block. Called by `deploy-to-wiki` for templates. |
| [`sync-codex-icons`](.agents/skills/sync-codex-icons/SKILL.md) | Reconcile `Category:Codex icons` on the wiki against the upstream `wikimedia/design-codex` repo. |
