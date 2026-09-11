# Template:Mainpage

Renders the wiki's main page as one full-bleed layout: hero band, event and patch highlights, featured article, on this day, an editing invitation, two community cards, and the site directory. Transclude it as the page's entire content.

## Usage

```wikitext
{{Mainpage}}
```

Nothing else is needed on the page: the template emits its own TemplateStyles and the tracking category that loads the enhancement gadget.

## Parameters

This template takes no parameters.

## Behavior

Everything an editor changes is in one page, `Module:Mainpage/settings.json`, linked at the foot of the rendered page. It is not tracked in this repository: it is wiki content rather than code, so the wiki page is its source of truth and keeps its own history.

| Section | Holds |
| --- | --- |
| `featured` | `page`, `text`. The picture is the article's own Page Image, so the page name is all there is to set. With no `page`, the card falls back to `Star Citizen`, deliberately not the main page itself, which would render as a self-link. |
| `event` | `name`, `page`, `text`, `starts`, `ends`, and one of `banner` or `image` (see below). Clearing `name` removes the card; clearing `ends` keeps the card and drops its countdown. |
| `patches` | One object per build chip: `channel`, `name`, `page`, `highlights`. `channel: "LIVE"` fills the live marker and the "this patch" card. |
| `hero` | `image`, `lede`, `ledeDetail`, `searchTails`. |
| `chips`, `directory` | Link lists: `{ "page": …, "label": … }` for this wiki, `{ "url": …, "label": … }` elsewhere; `label` is optional on a wiki link. |

The event card's picture chooses its design; set one key, not both, since with both, `banner` wins:

| Key | Design |
| --- | --- |
| `banner` | One of the 1080×83 strips in `Category:Main page banner images`, shown at the height it was drawn: a centred slice, not a shrunken whole. Check that its logo survives a centred crop, since a narrow column shows only about a quarter of the strip. |
| `image` | An ordinary screenshot: beside the text on a wide card, across the top on a narrow one. A banner strip set here crops to a smear. |

Naming the asset names the layout, so a design can't be paired with a picture it cannot show; switching between them is a settings edit, not a module edit.

A malformed value never takes the page down: an event date the clock cannot read costs only the clock, and a moved or deleted settings page costs only what it fed. Dates are read as `YYYY-MM-DD`, optionally with `HH:MM` or `HH:MM:SS` and a trailing `UTC`; anything else is treated as unset.

## See also

- [Module:Mainpage](https://starcitizen.tools/Module:Mainpage), implementation and the submodule index.
