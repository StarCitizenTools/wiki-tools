# MediaWiki namespace: gadgets

Client-side gadgets that enhance server-rendered pages, mirrored from the wiki's `MediaWiki:` namespace. [`Gadgets-definition.wikitext`](Gadgets-definition.wikitext) mirrors the whole registry (`MediaWiki:Gadgets-definition`); only the gadgets below have their files mirrored here, the rest are maintained on the wiki. A gadget loads only once its registry line names its files, its ResourceLoader dependencies, and the rights or page categories that gate it.

| Gadget | Files | Does |
|---|---|---|
| `aggridRenderers` | [`Gadget-aggridRenderers.js`](Gadget-aggridRenderers.js), [`.css`](Gadget-aggridRenderers.css) | Cell renderers and comparators for the AG Grid tables built by `Module:DataGrid`, `Module:AGGridColumns` and `Module:PledgeVehicleGrid`. Hidden; loads only on pages in `Category:Pages using AG Grid`. |
| `blame` | [`Gadget-blame.js`](Gadget-blame.js), [`Gadget-blame-text.js`](Gadget-blame-text.js), [`.css`](Gadget-blame.css), [`Gadget-blame.wikitext`](Gadget-blame.wikitext) | Per-word attribution of a page's current text to the revision that introduced it (word-level Myers diff over the history). Shown to users with the `noratelimit` right. |
| `mainpage` | [`Gadget-mainpage.js`](Gadget-mainpage.js), [`.css`](Gadget-mainpage.css) | Progressive enhancements over the main page that `Module:Mainpage` renders; the no-JS page is complete without it. Hidden; loads only on pages in `Category:Pages using main page gadget`. |
| `quantumUpload` | [`Gadget-quantumUpload.js`](Gadget-quantumUpload.js), [`.css`](Gadget-quantumUpload.css) | Upload control on the placeholder image `Module:InfoboxLua` emits when a page has no image of its own; needs the `verified-edit` right. |
| `Confetti`, `Lib-Canvas-Confetti` | [`Gadget-Confetti.js`](Gadget-Confetti.js), [`Gadget-Lib-Canvas-Confetti.js`](Gadget-Lib-Canvas-Confetti.js) | A confetti burst and the vendored canvas-confetti library behind it; `quantumUpload` loads it on demand after a successful upload. |

## Conventions

- A gadget reads its context from `data-gadget-<gadgetname>-<key>` attributes on the element it enhances, and its classes are `gadget-<gadgetname>-…`; `grep gadget-<name>-` finds every emitter and the owning gadget. Attribute segments stay lowercase in markup and are read as `el.dataset.gadget<Name><Key>`.
- Gadgets stay skin-portable: Codex `--color-*` and `--border-*` tokens with fallbacks, spacing in plain pixels, no Citizen-only tokens.
- Gadget JavaScript is tested with Node under `tests/js/` (`mise run test:js`); there is no on-wiki test surface for gadgets.
- Deploying a gadget means pushing each file to its `MediaWiki:` page and, for a new gadget, adding its registry line. A `Gadgets-definition` edit reaches every reader at once, so byte-verify the pushed files first.
