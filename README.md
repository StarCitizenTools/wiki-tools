# wiki-tools

Wiki pages, Scribunto modules, templates, gadgets, and automation for the [Star Citizen Wiki](https://starcitizen.tools).

## Repository layout

| Path | Contents |
|---|---|
| `pages/` | Mirror of the wiki, one directory per namespace. See [`pages/README.md`](pages/README.md) for the path rules and the catalog of every module and template. |
| `scripts/` | Go programs that generate wiki content from data the wiki does not maintain by hand, and report how it differs from the live wiki. See [`scripts/README.md`](scripts/README.md). |
| `tests/` | The local test layers: off-wiki ScribuntoUnit runner config, JSON manifest checks, Node tests for gadgets. See [`tests/README.md`](tests/README.md). |
| `tools/` | Audit and migration helpers kept from past content migrations. See [`tools/README.md`](tools/README.md). |
| `types/mw/` | LuaCATS stubs for the Scribunto `mw` API, mirrored from upstream `REL1_43`. |
| `design/` | Design references for first-party surfaces such as the main page. |
| `.agents/skills/` | Agent skills for the wiki workflows below. |
| `AGENTS.md` | Conventions for contributors and agents. Read it before changing anything under `pages/`. |

## Development

Install [mise](https://mise.jdx.dev), then:

```sh
mise install        # Toolchain, pinned in .mise.toml
lefthook install    # Pre-commit hooks: the same checks as `mise run lint`
mise run lint       # Formatting and consistency checks
mise run fix        # Auto-fix formatting
mise run test       # Every local test layer; `mise tasks` lists them individually
```

Lint and tests are merge-blocking in CI (`.github/workflows/`). The Lua suites run off-wiki and need a system `lua5.1`; see [`tests/README.md`](tests/README.md). Anything that depends on the live wiki is checked on a sandbox page instead, as described in `AGENTS.md`.

## Agent skills

Project skills under `.agents/skills/`. Describe the task in plain English and the agent picks the matching skill.

| Skill | Use it for |
|---|---|
| [`deploy-to-wiki`](.agents/skills/deploy-to-wiki/SKILL.md) | Push a local module or template to the wiki, including its `/doc` page. |
| [`sync-from-wiki`](.agents/skills/sync-from-wiki/SKILL.md) | Pull upstream wiki edits into the local mirror, the inverse of deploy. |
| [`doc-page-from-readme`](.agents/skills/doc-page-from-readme/SKILL.md) | Convert a README to the wikitext of its `/doc` page. Called by `deploy-to-wiki`. |
| [`templatedata-from-readme`](.agents/skills/templatedata-from-readme/SKILL.md) | Convert a README's Parameters table to a `<templatedata>` block. Called by `deploy-to-wiki` for templates. |
| [`sync-codex-icons`](.agents/skills/sync-codex-icons/SKILL.md) | Reconcile `Category:Codex icons` on the wiki against the upstream Codex repository. |
| [`import-patch-notes`](.agents/skills/import-patch-notes/SKILL.md) | Import a patch's release notes into the `Update:` namespace. |
| [`expand-stub-with-source`](.agents/skills/expand-stub-with-source/SKILL.md) | Grow a stub article from official RSI sources, cited. |
| [`migrate-category-to-entity`](.agents/skills/migrate-category-to-entity/SKILL.md) | Move every page in a `Category:<Type>` from the legacy `{{Item}}` template onto `{{Entity}}`. |
| [`overhaul-company-page`](.agents/skills/overhaul-company-page/SKILL.md) | Bring a company page up to the current `{{Company}}` conventions. |
