# wiki-tools

Wiki pages, modules, and automation for [Star Citizen Wiki](https://starcitizen.tools).

## Pages

Files in `pages/` map to wiki pages by namespace. Each file deploys to its corresponding wiki page.

| Page | Description |
|---|---|
| [Module:InfoboxLua](pages/module/InfoboxLua) | Data-driven infobox system with collapsible sections, tabs, and multi-column layouts. |
| [Module:Details](pages/module/Details) | Wrapper for creating collapsible content sections. |
| [Module:ScribuntoUnit](pages/module/ScribuntoUnit) | Unit testing framework for Scribunto modules. |

## Development

Formatting is enforced by linters. Requires [mise](https://mise.jdx.dev).

```sh
mise run lint    # Check
mise run fix     # Fix
```

## Deployment

Deploy a module to the wiki with the `deploy-to-wiki` agent skill:

```
deploy Details
```

This handles file-to-page mapping, diff checking with confirmation, and markdown-to-wikitext conversion for documentation pages.
