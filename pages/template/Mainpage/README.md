# Template:Mainpage

Renders the wiki's main page as one full-bleed sequence of content bands, transcluded as the page's entire content.

## Usage

```wikitext
{{Mainpage}}
```

The template emits its own [TemplateStyles](https://www.mediawiki.org/wiki/Extension:TemplateStyles) and the tracking category that loads the enhancement gadget.

## Parameters

This template takes no parameters.

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|

## Behavior

The page runs: a hero band, event and patch highlights, the featured article, on this day, an editing invitation, two community cards, and the site directory.

Everything an editor changes is in `Module:Mainpage/settings.json`, linked at the foot of the page. It is not tracked in this repository: it is wiki content, so the wiki page is its own source of truth. That page carries its own guidance in a `_readme` key; any `_`-prefixed key is dropped as guidance, not data.

| Section | Holds |
| --- | --- |
| `featured` | `page`, `text`, `image`, the picture named bare as in `hero`. With no `image` the card shows the placeholder; with no `page` it falls back to `Star Citizen`, never a self-link. |
| `event` | `name`, `page`, `text`, `starts`, `ends`, and one of `banner` or `image` (see below). Clearing `name` removes the card; clearing `ends` keeps the card and drops its countdown. |
| `patches` | One object per build chip: `channel`, `name`, `page`, `highlights`. `channel: "LIVE"` marks the current chip; with none marked, the first chip with a `name` is used instead. |
| `hero` | `image`, `lede`, `ledeDetail`, `searchTails`. |
| `chips` | Link lists (`{ "page": …, "label": … }` on-wiki, `{ "url": …, "label": … }` elsewhere; `label` optional on a wiki link): the strip under the hero. |
| `directory` | Groups of `{ "label": …, "links": [ … ] }`, links shaped as in `chips`: the foot groups. |

The event card's picture chooses its design; set one key, not both, since with both, `banner` wins:

| Key | Design |
| --- | --- |
| `banner` | One of the 1080×83 strips in `Category:Main page banner images`, shown at the height it was drawn as a centred slice (about a quarter of the strip in the narrowest column). Check its logo survives that crop. |
| `image` | An ordinary screenshot: beside the text on a wide card, across the top on a narrow one. A banner strip set here crops to a smear. |

Naming the asset picks the layout, so a design can't be paired with an unusable picture; switching is a settings edit, not a module edit.

A malformed value never takes the page down: an unreadable event date costs only the clock, and a moved or deleted settings page costs only what it fed. Dates are read as `YYYY-MM-DD`, optionally with a space or `T` then `HH:MM`/`HH:MM:SS`, and a trailing `UTC`/`Z`; anything else is unset.

## See also

- [Module:Mainpage](https://starcitizen.tools/Module:Mainpage), implementation and the submodule index.
