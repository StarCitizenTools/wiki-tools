# Module:Documentation

Draws the documentation header on module and template pages and the notices under it, including the folded Technical details panel.

Editors reach it through [Template:Documentation](https://starcitizen.tools/Template:Documentation).

## For module editors

### Gotchas

- The Technical details panel is [Module:Dependencies](https://starcitizen.tools/Module:Dependencies)'s. This module fills its Source row from `{{Documentation}}`: `git=` adds a line linking its root page's directory in the wiki-tools repository, and `fromWikipedia=` a line linking the same title on the English Wikipedia.
- Module:Dependencies runs inside `pcall`: an error in it, or in a module it requires, prints in place of the panel instead of breaking every documentation page.
