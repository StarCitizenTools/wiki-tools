# Template:IconLink

Renders an inline icon link: a small icon followed by a text label, where both the icon and the label link to the same wiki page. Suited to compact, scannable references such as a ship with a thumbnail, a manufacturer with its logo, or a location with a map pin. Wraps [Module:IconLink](https://starcitizen.tools/Module:IconLink); see the module page for rendering details. For an icon beside plain, non-linking text, use [Template:IconText](https://starcitizen.tools/Template:IconText).

## Usage

The first positional argument is the target page; `icon` is the file name of the leading glyph. `text` overrides the visible label (which defaults to the page name); `size` sets the icon size; `class` appends a CSS class to the root span.

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{IconLink\|Aurora MR\|icon=CdxIconArticle.svg}}</syntaxhighlight> | {{IconLink\|Aurora MR\|icon=CdxIconArticle.svg}} |
| <syntaxhighlight inline lang="wikitext">{{IconLink\|Stanton system\|text=Stanton\|icon=CdxIconMapPin.svg}}</syntaxhighlight> | {{IconLink\|Stanton system\|text=Stanton\|icon=CdxIconMapPin.svg}} |
| <syntaxhighlight inline lang="wikitext">{{IconLink\|Aurora MR\|icon=CdxIconImage.svg\|size=16px}}</syntaxhighlight> | {{IconLink\|Aurora MR\|icon=CdxIconImage.svg\|size=16px}} |

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Link | wiki-page-name | Yes |  | Target wiki page. Both the icon and the label link here. Alias: `link` (takes precedence over the positional argument). | `Aurora MR` |
| `icon` | Icon | wiki-file-name | Yes |  | File name (without the `File:` prefix) of the leading icon. | `CdxIconArticle.svg` |
| `text` | Text | string | No | (the link target) | Visible label. Defaults to the page name. | `Aurora` |
| `size` | Icon size | string | No | `20px` | Icon size, as a MediaWiki image size. | `16px` |
| `class` | CSS class | string | No |  | Extra class appended to the root span. | `my-icon-link` |

## Behavior

- The icon and the text sit in a single inline-flex span, so they stay on one line with a small gap and align vertically centered.
- The icon is rendered with `class=metadata`, which excludes it from MultimediaViewer; clicking it follows the same link as the text.
- `link` is an accepted alias for the first positional argument. If both are supplied, `link` takes precedence.
- If `icon` is omitted, or if no link is given, the module raises a script error.

## See also

- [Module:IconLink](https://starcitizen.tools/Module:IconLink) — implementation.
- [Template:IconText](https://starcitizen.tools/Template:IconText) — an icon beside non-linking text.
