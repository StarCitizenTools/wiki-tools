# Module:Hatnote

Builds hatnotes, the one-line notes at the top of an article that point readers to a related or similarly named page, for Template:Hatnote and the other hatnote modules, which call its `_hatnote` and link helpers. Imported from Wikipedia; [Module:Mbox](https://starcitizen.tools/Module:Mbox) draws the box.

Editors reach it through [Template:Hatnote](https://starcitizen.tools/Template:Hatnote), through the hatnote modules behind the other hatnote templates ([Module:Main](https://starcitizen.tools/Module:Main), [Module:For](https://starcitizen.tools/Module:For), [Module:About](https://starcitizen.tools/Module:About), [Module:Redirect hatnote](https://starcitizen.tools/Module:Redirect_hatnote), [Module:Labelled list hatnote](https://starcitizen.tools/Module:Labelled_list_hatnote) and [Module:Hatnote list](https://starcitizen.tools/Module:Hatnote_list)), and through [Module:Documentation](https://starcitizen.tools/Module:Documentation) and [Module:Navplate vehicles](https://starcitizen.tools/Module:Navplate_vehicles).

## For module editors

### API

- `p._hatnote(s, options) → string`: a notice-type Mbox with `s` as its title and `role="note"`. `options.icon` names a file; `options.extraclasses` and `options.selfref` add classes. `options.inline == 1` returns a plain `<span>` without the box, for a note inside running text.
- `p.hatnote(frame)`: the `{{#invoke:Hatnote|hatnote}}` entry behind Template:Hatnote. Reads the calling template's arguments.
- Helpers: `defaultClasses(inline)`, `disambiguate(page, disambiguator)`, `findNamespaceId(link, removeColon)`, `makeWikitextError(msg, helpLink, addTrackingCategory, title)`, `missingTargetCat`, `quote(title)`.

### Gotchas

- The hatnote modules named above call this module's functions by name, so those names and signatures are a contract. Change the box in Module:Mbox, not here.
- Module:Mbox puts callers under strict mode, so a module that requires Hatnote must declare its variables `local`.
