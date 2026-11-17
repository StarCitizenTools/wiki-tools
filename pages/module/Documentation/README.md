# Module:Documentation

Draws the documentation header on module and template pages and on their `/doc` subpages, followed by the folded Technical details panel.

Editors reach it through [Template:Documentation](https://starcitizen.tools/Template:Documentation).

## For module editors

### Gotchas

- The wrapper `<div>` holds only the header and the notices, never the `/doc` content after it: an unclosed wrapper puts a missing-end-tag lint error on every documented page. Styles aimed at the content therefore select later siblings of `.t-documentation`.
- The Technical details panel is [Module:Dependencies](https://starcitizen.tools/Module:Dependencies)'s. This module fills its Source row from `{{Documentation}}`: `git=` adds a line linking its root page's directory in the wiki-tools repository, and `importedFrom=` (or `fromWikipedia=`) a line naming where it came from.
- Module:Dependencies runs inside `pcall`: an error in it, or in a module it requires, prints in place of the panel instead of breaking every documentation page.
- `git=` adds a modifier class, and the stylesheet hides [Extension:TemplateData](https://www.mediawiki.org/wiki/Extension:TemplateData)'s description when it follows a wrapper carrying it. The README converter makes a page's first paragraph its TemplateData description, so it would otherwise show twice.
- On a module's `/doc` page, the band is the only notice because `MediaWiki:Scribunto-doc-page-header` is empty on the wiki. Scribunto prints that message without checking whether it is disabled, so `-` would show as a literal dash.
