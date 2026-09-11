# Module:Countdown

A live countdown display, split by responsibility: the module renders the markup, the data attributes, and a no-JS fallback date; a mainpage gadget computes the actual remaining time and animates the digit stack client-side.

Required by [Module:Mainpage/Event/Event](https://starcitizen.tools/Module:Mainpage/Event/Event) and [Module:Mainpage/Event/Legacy](https://starcitizen.tools/Module:Mainpage/Event/Legacy); not invoked from templates.

## For module editors

### API

`p.render(props)` returns `<templatestyles>` + markup, or raises a Lua error when `ends` is missing or either date is not readable by the content language's date formatter (`mw.language:formatDate`); both current callers wrap the call in `pcall`.

| Field | Type | Description |
|---|---|---|
| `starts` | ISO 8601 string | Optional. Omit for something already under way; with it the gadget can also render a "starts in" tense. |
| `ends` | ISO 8601 string | Required. |
| `label` | `string` | Overrides the gadget's tense-derived label. Rarely wanted; the point is that the label follows the dates. |
| `class` | `string` | Extra class on the root. |

`p.main(frame)` is the `#invoke` entry point (reads `starts`/`ends`/`label`/`class` via [Module:Arguments](https://starcitizen.tools/Module:Arguments)).

### Gotchas

- The module deliberately does not compute remaining time: a value worked out at parse time freezes into the parser cache and can go arbitrarily stale. It emits the dates as `data-gadget-mainpage-countdown-start`/`-end` (+ `-label`) attributes for the gadget, and renders a no-JS fallback: the end date alone, or a `starts – ends` range with the start year dropped when both dates share one.
- An unreadable date is a hard Lua error, not a silent empty render, because a typo here has to be loud.

### Styles

`class = 't-countdown--flat'` is the module's own modifier for lying the clock down into a horizontal strip regardless of viewport (it also does this automatically below 639px). The gadget replaces the fallback with a live digit stack, adding `t-countdown--live` and, for colour, one of `--upcoming` or `--running`; `--ended` carries no colour rule at all, deliberately falling back to the root's `--color-subtle`.
