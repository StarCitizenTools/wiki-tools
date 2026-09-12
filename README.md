# wiki-tools

Wiki pages, Scribunto modules, templates, gadgets, and automation for the [Star Citizen Wiki](https://starcitizen.tools).

## Repository layout

| Path | Contents |
|---|---|
| `pages/` | Mirror of the wiki, one directory per namespace. See [`pages/README.md`](pages/README.md) for the path rules and the catalog of every module and template. |
| `scripts/` | Go programs that generate wiki content from data the wiki does not maintain by hand, and report how it differs from the live wiki. See [`scripts/README.md`](scripts/README.md). |
| `tests/` | The local test layers. See [`tests/README.md`](tests/README.md). |
| `tools/` | Audit and migration helpers kept from past content migrations. See [`tools/README.md`](tools/README.md). |
| `types/mw/` | LuaCATS stubs for the Scribunto `mw` API. |
| `design/` | Design references for first-party surfaces. |
| `.agents/skills/` | Agent skills, one directory per wiki workflow. |
| `AGENTS.md` | Conventions for contributors and agents. Read it before changing anything under `pages/`. |

## Development

Install [mise](https://mise.jdx.dev), then:

```sh
mise install        # Toolchain, pinned in .mise.toml
lefthook install    # Pre-commit formatting hooks
mise run lint       # Formatting and consistency checks
mise run fix        # Auto-fix formatting
mise run test       # Every local test layer; `mise tasks` lists them individually
```

Lint and tests are merge-blocking in CI (`.github/workflows/`). Anything that depends on the live wiki is checked on a sandbox page instead, as described in `AGENTS.md`.

## Agent skills

Project skills live under `.agents/skills/`, one directory per workflow: deploying and syncing pages, converting READMEs to documentation pages, and content migrations. Each `SKILL.md` says when to use it; describe the task in plain English and the agent picks the matching skill.
