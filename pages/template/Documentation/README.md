# Template:Documentation

The documentation header on module and template pages. Place it at the top of every `/doc` subpage.

## Usage

```wikitext
{{Documentation}}
```

For a page kept in the wiki-tools repository, or imported from another wiki:

```wikitext
{{Documentation|git=true|importedFrom=[https://runescape.wiki/w/Module:Module_toc RuneScape Wiki]}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `1` | Documented page | wiki-page-name | No |  | Page the header's links point to, when it is not the page this `/doc` belongs to. | `Template:Foo` |  |
| `git` | Synced with wiki-tools | boolean | No |  | Adds a Source line linking the page's directory in the wiki-tools repository. The README converter sets it on every page it deploys. | `true` |  |
| `importedFrom` | Imported from | content | No |  | Where the page came from, as a wikitext link. Adds "Imported from" and the link to the Source line. | `[https://runescape.wiki/w/Module:Module_toc RuneScape Wiki]` |  |
| `fromWikipedia` | Imported from Wikipedia | boolean | No |  | Shorthand for `importedFrom` linking the same title on the English Wikipedia. | `true` |  |
| `category` | Add categories | boolean | No | `yes` | Set to `no` to stop the Technical details panel adding its categories: Lua-based templates, Strict mode modules and Unused modules. | `no` |  |

## Behavior

- The header links to the `/doc` page and offers Edit, History and Purge. Viewed on its own, the `/doc` page shows a Documentation subpage header linking back instead.
- Below the header, the folded Technical details panel lists where the page comes from, which pages use it, what it uses, and a module's functions.
- A rule marks where the documentation ends.
- On a `git=true` page, the parameter table's own description is hidden: the page's first paragraph already says the same thing.
- Categories: a module page joins Modules, and a page with `importedFrom` or `fromWikipedia` joins Imported modules or Imported templates. The `/doc` page itself joins Modules documentation or Templates documentation instead, sorted by its base page name.

## See also

- [Module:Documentation](https://starcitizen.tools/Module:Documentation), which draws the header.
- [Module:Dependencies](https://starcitizen.tools/Module:Dependencies), which draws the Technical details panel.
