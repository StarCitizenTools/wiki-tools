# Template:IconText

Renders an inline icon and text pair: a small icon followed by a plain text label, neither of which links anywhere. The icon is inert decoration and the label is plain text. Suited to compact inline metadata such as a clock beside a duration, a map pin beside a location, or a status glyph beside a label. Wraps [Module:IconText](https://starcitizen.tools/Module:IconText); see the module page for rendering details. For an icon and label that both link to a page, use [Template:IconLink](https://starcitizen.tools/Template:IconLink).

## Usage

The first positional argument is the text label; `icon` is the file name of the leading glyph. `size` sets the icon size; `class` appends a CSS class to the root span.

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{IconText\|5 minutes\|icon=CdxIconClock.svg}}</syntaxhighlight> | {{IconText\|5 minutes\|icon=CdxIconClock.svg}} |
| <syntaxhighlight inline lang="wikitext">{{IconText\|Stanton\|icon=CdxIconMapPin.svg}}</syntaxhighlight> | {{IconText\|Stanton\|icon=CdxIconMapPin.svg}} |
| <syntaxhighlight inline lang="wikitext">{{IconText\|Warning\|icon=CdxIconError.svg\|size=16px}}</syntaxhighlight> | {{IconText\|Warning\|icon=CdxIconError.svg\|size=16px}} |
| <syntaxhighlight inline lang="wikitext">{{IconText\|5 minutes\|icon=CdxIconClock.svg\|mask=yes}}</syntaxhighlight> | {{IconText\|5 minutes\|icon=CdxIconClock.svg\|mask=yes}} |

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Text | string | Yes |  | Visible text label. Alias: `text` (takes precedence over the positional argument). | `5 minutes` |
| `icon` | Icon | wiki-file-name | Yes |  | File name (without the `File:` prefix) of the leading icon. | `CdxIconClock.svg` |
| `iconTitle` | Icon tooltip | string | No |  | Tooltip shown when hovering the icon; also sets the icon's alt text. | `Estimated time` |
| `size` | Icon size | string | No | `20px` | Icon size, as a MediaWiki image size. | `16px` |
| `mask` | Mask icon | boolean | No | `false` | Render the icon as a recolorable CSS mask filled with the current text color, instead of an image. | `yes` |
| `class` | CSS class | string | No |  | Extra class appended to the root span. | `my-icon-text` |

## Behavior

- The icon and the text sit in a single inline-flex span, so they stay on one line with a small gap and align vertically centered.
- The icon is rendered with an empty `link=` and `class=metadata`, so it is not clickable and is excluded from MultimediaViewer — it reads as inert decoration.
- `iconTitle`, when supplied, becomes the icon's hover tooltip (the `title` attribute) and its `alt` text; without it the icon has no tooltip.
- `mask` swaps the `<img>` for a CSS mask filled with `background-color: currentColor`, so the icon takes on the surrounding text color and recolors with it. Provide a single-color (for example Codex) icon for the best result.
- `text` is an accepted alias for the first positional argument. If both are supplied, `text` takes precedence.
- If `icon` or the text is omitted, the module raises a script error.

## See also

- [Module:IconText](https://starcitizen.tools/Module:IconText) — implementation.
- [Template:IconLink](https://starcitizen.tools/Template:IconLink) — an icon and label that link to a page.
