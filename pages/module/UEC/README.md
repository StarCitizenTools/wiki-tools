# Module:UEC

Formats an in-game money value in [United Earth Credit](https://starcitizen.tools/United_Earth_Credit) (UEC): the UEC glyph followed by the amount with thousands separators. Built on [Module:IconText](https://starcitizen.tools/Module:IconText), with the icon in mask mode so it recolors with the surrounding text.

Editors use this through `{{UEC}}`; see [Template:UEC](https://starcitizen.tools/Template:UEC). Required directly by [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), [Module:Entity/Acquisition](https://starcitizen.tools/Module:Entity/Acquisition), and [Module:Entity/Vehicle/Cost](https://starcitizen.tools/Module:Entity/Vehicle/Cost) for formatting price values.

## For module editors

### API

- `p.main(frame)`: wikitext entry point behind `{{UEC}}`; the first positional argument is the amount.
- `p._main(uec)`: a number or numeric string, returning the rendered string (glyph plus grouped amount). Raises an error if the value isn't numeric.
- `p._range(min, max)`: the glyph followed by "min–max" (both grouped), collapsing to a single value when `min == max`. Meant for sibling modules; [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) uses it for UEX price ranges. Both bounds must be numeric, otherwise it raises an error.

### Gotchas

- The amount is formatted with `mw.language.getContentLanguage():formatNum`, so its digit grouping follows the wiki's content language rather than a hardcoded comma.
