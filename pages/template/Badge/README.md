# Template:Badge

Renders an inline badge: a small pill-shaped label suited for status tags, version markers, faction labels, or any short metadata that should read as a distinct chip rather than plain text. Wraps [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua); see the module page for rendering details.

## Usage

The first positional argument is the badge text. `variant` themes the badge via Citizen design tokens; `color`/`backgroundColor` (or its `bg` shorthand) override those tokens with literal CSS values; `icon` adds a 16px image before the text.

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{Badge\|Aurora}}</syntaxhighlight> | {{Badge\|Aurora}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Genesis\|variant=warning}}</syntaxhighlight> | {{Badge\|Genesis\|variant=warning}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Caterpillar\|variant=error}}</syntaxhighlight> | {{Badge\|Caterpillar\|variant=error}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|Carrack\|variant=success}}</syntaxhighlight> | {{Badge\|Carrack\|variant=success}} |
| <syntaxhighlight inline lang="wikitext">{{Badge\|30K\|icon=CdxIconError.svg\|bg=#2a6df4\|color=#fff}}</syntaxhighlight> | {{Badge\|30K\|icon=CdxIconError.svg\|bg=#2a6df4\|color=#fff}} |

## Parameters

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `1` | Text | string | Yes |  | Badge label. Wikitext is allowed. | `New` |  |
| `variant` | Variant | string | No |  | Semantic preset that themes the badge via Citizen design tokens: one of `error`, `success`, `warning`. | `warning` |  |
| `icon` | Icon | wiki-file-name | No |  | File name (without the `File:` prefix) of an icon rendered before the text at 16px. | `Sparkle.svg` |  |
| `mask` | Mask icon | boolean | No | `false` | Render the icon as a recolorable CSS mask filled with the badge text color, instead of an image. | `yes` |  |
| `color` | Text color | string | No |  | CSS color applied to the badge text, overriding `variant`. | `#fff` |  |
| `backgroundColor` | Background color | string | No |  | CSS background color applied to the badge, overriding `variant`. | `#2a6df4` | `bg` |
| `link` | Link | wiki-page-name | No |  | Wrap the whole badge in a single anchor to this page. | `Aurora MR` |  |
| `class` | CSS class | string | No |  | Extra class appended to the badge root. | `my-badge` |  |

## Behavior

- `bg` is an alias for `backgroundColor`; an explicit `backgroundColor=` wins if both are given.
- `variant` and the raw `color`/`backgroundColor` props are independent axes. Setting both is allowed: the inline color overrides the variant's text/background color but the variant's border color is kept unless the caller adds their own.
- Unknown `variant` values are silently ignored (the badge falls back to the default surface color), so a typo never produces a broken-looking class like `t-badge--warnng`.
- The icon image is rendered with `class=metadata|link=` so it's excluded from MultimediaViewer and is not clickable, and the badge reads as inert decoration.
- Badges are never underlined, even when wrapped via `link`.

## See also

- [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua), the implementation.
