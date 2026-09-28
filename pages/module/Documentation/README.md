# Module:Documentation

Draws the documentation header on module and template pages and on their `/doc` subpages, followed by the folded Technical details panel.

Editors reach it through [Template:Documentation](https://starcitizen.tools/Template:Documentation).

## For module editors

### Gotchas

- `doc()` opens its wrapper `<div>` and never closes it. `{{Documentation}}` sits at the top of the `/doc` page, so the wrapper holds everything after it until the parser closes it at the end; the rule under the documentation is the wrapper's border.
- The Technical details panel is [Module:Dependencies](https://starcitizen.tools/Module:Dependencies)'s. This module fills its Source row from `{{Documentation}}`: `git=` adds a line linking its root page's directory in the wiki-tools repository, and `importedFrom=` (or `fromWikipedia=`) a line naming where it came from.
- Module:Dependencies runs inside `pcall`: an error in it, or in a module it requires, prints in place of the panel instead of breaking every documentation page.
- `git=` adds a modifier class under which the stylesheet hides [Extension:TemplateData](https://www.mediawiki.org/wiki/Extension:TemplateData)'s description. The README converter makes a page's first paragraph its TemplateData description, so it would otherwise show twice.
- On a module page, Scribunto shows the doc through its `scribunto-doc-page-show` message, which ends with an `<hr>` that lands inside the wrapper; the stylesheet hides it. On a module's `/doc` page, the band is the only notice because `MediaWiki:Scribunto-doc-page-header` is empty on the wiki. Scribunto prints that message without checking whether it is disabled, so `-` would show as a literal dash.
