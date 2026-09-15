# Template:Removed

Hatnote marking a page or section that describes content removed from ''Star Citizen'', and the categoriser that tracks it. Put it at the top of an article the game no longer backs, so a reader knows before reading that none of it is currently in the game.

## Usage

```wikitext
{{Removed}}
{{Removed|what=contract}}
{{Removed|what=contract|category=Removed contracts}}
{{Removed|why=Reworked into the Contract Manager in Alpha 3.15}}
```

An infobox template for a kind of removed content transcludes this rather than repeating the banner and the category. [Template:Removed contract](https://starcitizen.tools/Template:Removed_contract) does exactly that, passing its own `what` and `category`.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `what` | What | string | No | `page or section` | What is being marked, in the singular, so the banner reads as a sentence. | `contract` | `Subject` |
| `why` | Reason | string | No |  | Why the content was removed, or what replaced it. Shown when the banner is hovered. | `Reworked into the Contract Manager in Alpha 3.15` | `Reason` |
| `category` | Category | string | No | `Removed content` | Tracking category to file the page in, without the `Category:` prefix. Pass a subcategory to track one kind of removed content. | `Removed contracts` |  |

## Behavior

The banner states the removal; the detail, including `why`, appears when it is hovered, which is how the other [mbox](https://starcitizen.tools/Module:Mbox/styles.css) banners behave.

Removed content is marked rather than deleted because the game data no longer carries it, so the article is the only surviving description. That is also why nothing here is recorded as queryable data: a page in this category must not appear in a list of things a player can go and do.

Pass `category` a subcategory and make that subcategory a member of [Category:Removed content](https://starcitizen.tools/Category:Removed_content), so the site-wide tracking stays complete while each kind keeps its own bucket.

## See also

- [Template:Removed contract](https://starcitizen.tools/Template:Removed_contract) for a removed contract's infobox
- [Template:Outdated](https://starcitizen.tools/Template:Outdated) for content that still exists but is described out of date
