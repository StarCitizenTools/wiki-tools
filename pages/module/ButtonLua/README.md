# Module:ButtonLua

Renders a [Codex](https://doc.wikimedia.org/codex/latest/components/demos/button.html) button as a link: a fake-button `<span>` wrapping a wikilink or external link, with optional icon, action, weight, and size variants.

Required by [Module:CardLua](https://starcitizen.tools/Module:CardLua), [Module:Mainpage/Community](https://starcitizen.tools/Module:Mainpage/Community), [Module:Mainpage/Editing](https://starcitizen.tools/Module:Mainpage/Editing), [Module:Entity/Infobox](https://starcitizen.tools/Module:Entity/Infobox), and [Module:Company](https://starcitizen.tools/Module:Company); not invoked from templates.

## For module editors

### API

`p.render(props)` returns an HTML string with `<templatestyles>` for [Module:ButtonLua/styles.css](https://starcitizen.tools/Module:ButtonLua/styles.css) included.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | `string` | Yes | | Button text; becomes the `aria-label` when `iconOnly` is set. |
| `link` | `string` | one of `link`/`url` | | Wiki page, rendered as `[[link\|…]]`. |
| `url` | `string` | one of `link`/`url` | | External URL, rendered as `[url …]`. |
| `action` | `string` | No | `default` | `default`, `progressive`, or `destructive`. |
| `weight` | `string` | No | `normal` | `normal` or `primary`. |
| `size` | `string` | No | `medium` | `small`, `medium`, or `large`. |
| `icon` | `string` | No | | Icon file name. MediaWiki disallows `<img>` inside `<a>`, so it renders as a `currentColor` mask instead of an `<img>`. |
| `iconOnly` | `boolean` | No | `false` | Hide the label; requires `icon`. |
| `disabled` | `boolean` | No | `false` | Disabled visual style. |
| `class` | `string` | No | | Extra CSS class(es) on the button. |

`p.main(frame)` is the `#invoke` entry point, reading arguments via [Module:Arguments](https://starcitizen.tools/Module:Arguments).

### Gotchas

- `render` errors only when both `link` and `url` are absent; passing both is not rejected and renders two separate links (wikilink then external link) concatenated in the same span.
- Codex exposes only small and medium icon sizes: a `size = 'large'` button still gets a medium icon.
- The icon is a CSS mask stashed as a custom property (`--t-button-icon-url`) and consumed bare in `styles.css`, because the sanitizer rejects `url(var())` inline but allows `image-set()` and a bare `var()`.

### Styles

A brand button opts in with `class = 't-button--branded t-button--<brand>'`; the brand block sets `--t-button-ground` (and `color`), and hover/active shades derive from it via `color-mix`. [Module:ButtonLua/styles.css](https://starcitizen.tools/Module:ButtonLua/styles.css) currently declares seven: `wiki-api`, `galactapedia`/`starmap` (shared, same mark), `verseguide`, `patreon`, `kofi`, and `discord`; a consumer can declare its own brand block in its own stylesheet instead of adding one here.
