# Template:Badge

Renders an inline badge — a small pill-shaped label suited for status tags, version markers, faction labels, or any short metadata that should read as a distinct chip rather than plain text. Wraps [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua); see the module page for rendering details.

## Usage

The first positional argument is the badge text. `variant` themes the badge via Citizen design tokens; `color`/`bg` override those tokens with literal CSS values; `icon` adds a 16px image before the text.

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{Badge\|Aurora}}</syntaxhighlight> | {{Badge\|Aurora}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Genesis\|variant=warning}}</syntaxhighlight> | {{Badge\|Genesis\|variant=warning}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Caterpillar\|variant=error}}</syntaxhighlight> | {{Badge\|Caterpillar\|variant=error}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Carrack\|variant=success}}</syntaxhighlight> | {{Badge\|Carrack\|variant=success}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|30K\|icon=CdxIconError.svg\|bg=#2a6df4\|color=#fff}}</syntaxhighlight> | {{Badge\|30K\|icon=CdxIconError.svg\|bg=#2a6df4\|color=#fff}} |

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Text | string | Yes |  | Badge label. Wikitext is allowed. | `New` |
| `variant` | Variant | string | No |  | Semantic preset that themes the badge via Citizen design tokens. One of `error`, `success`, `warning`. Unknown values are ignored. | `warning` |
| `icon` | Icon | wiki-file-name | No |  | File name (without the `File:` prefix) of an icon rendered before the text at 16px. | `Sparkle.svg` |
| `color` | Text color | string | No |  | CSS color applied to the badge text. Overrides `variant`. | `#fff` |
| `bg` | Background color | string | No |  | CSS background color applied to the badge. Overrides `variant`. Alias: `backgroundColor`. | `#2a6df4` |
| `class` | CSS class | string | No |  | Extra class appended to the badge root. | `my-badge` |

## Behavior

- `variant` and the raw `color`/`bg` props are independent axes. Setting both is allowed — the inline color overrides the variant's text/background color but the variant's border color is kept unless the caller adds their own.
- Unknown `variant` values are silently ignored (the badge falls back to the default surface color), so a typo never produces a broken-looking class like `t-badge--warnng`.
- The icon image is rendered with `class=metadata|link=` so it's excluded from MultimediaViewer and is not clickable — the badge reads as inert decoration.

## See also

- [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) — implementation.
