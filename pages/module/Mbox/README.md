# Module:Mbox

The box behind page notices, hatnotes and empty sections: a title, an optional body that opens in place, a colour for the notice type, and an optional icon.

Editors reach it through the notice templates (such as [Template:Outdated](https://starcitizen.tools/Template:Outdated), [Template:Stub](https://starcitizen.tools/Template:Stub) and [Template:Removed](https://starcitizen.tools/Template:Removed)), every hatnote template through [Module:Hatnote](https://starcitizen.tools/Module:Hatnote), the Entity section templates through [Module:Entity/EmptyState](https://starcitizen.tools/Module:Entity/EmptyState), and module and template documentation pages through [Module:Documentation](https://starcitizen.tools/Module:Documentation) and [Module:Dependencies](https://starcitizen.tools/Module:Dependencies).

## For module editors

### API

- `p.render(props) → string`: the templatestyles tags followed by the box.

  | Field | Type | Default | Meaning |
  |---|---|---|---|
  | `title` | string | required | Headline wikitext. |
  | `text` | string | none | Body wikitext. Given, the box is a `<details>` that starts closed. |
  | `type` | string | `notice` | `notice`, `warning` or `error`. Any other value is `notice`. |
  | `icon` | string | none | File name without `File:`. No icon when omitted. |
  | `iconMask` | boolean | `true` | `false` renders a 14px `[[File:]]` thumbnail instead of a mask, for a multi-colour image. |
  | `placeholder` | boolean | `false` | Dashed box standing in for an empty section. |
  | `open` | boolean | `false` | Body starts open. |
  | `class` | string | none | Extra classes on the root, such as `metadata` or `plainlinks`. |

- `p.main(frame)`: the `#invoke` entry. Reads `title` (or `1`), `text` (or `2`), `type`, `icon`, `iconmask`, `placeholder`, `open` and `class` from the invocation only, so a calling template's own `type` parameter never reaches the box.
- `p._mbox(title, text, options)`: the Lua entry Module:Documentation calls. Takes `options.icon` and `options.extraclasses`, whose `mbox-low`, `mbox-med` and `mbox-high` tokens become `notice`, `warning` and `error`; other tokens pass through as classes.

### Gotchas

- A box with `text` is built by [Module:Details](https://starcitizen.tools/Module:Details). A strip marker in its title or body (`<nowiki>`, `<ref>`) prints a literal `{{#parsoidfragment}}` under Parsoid read views (upstream bug [T432547](https://phabricator.wikimedia.org/T432547)); the default read view is unaffected.
- A link in the title of a box with a body sits inside `<summary>`: clicking the link follows it instead of opening the box.
- Every box carries `navigation-not-searchable` and `noexcerpt`, which keep its text out of search results and page extracts.
- A placeholder carries no `role`, since it stands in for the section's content; every other title-only box is `role="note"`.
- Mbox, [Module:Icon](https://starcitizen.tools/Module:Icon) and Module:Details load `require('strict')`, which covers the whole `#invoke`: a module that requires Mbox or Module:Hatnote must declare its variables `local` (removing strict from Mbox would not help, since Icon and Details still load it).

### Styles

`styles.css` owns every `t-mbox` class; nothing outside it should target them.
