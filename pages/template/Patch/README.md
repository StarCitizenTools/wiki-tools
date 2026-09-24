# Template:Patch

Shows a game update's release status and links to the previous and next update. Use it once, at the top of every `Update:` page.

## Usage

```wikitext
{{Patch
| prev = Star Citizen Alpha 4.9.0
| next = Star Citizen Alpha 4.10.1
| version = 4.10.0
| build = 4.10.0-LIVE.12519617
| date = 2026-08-26
}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `prev` | Previous update | wiki-page-name | No |  | Page name of the previous update, without `Update:`. | `Star Citizen Alpha 4.9.0` |  |
| `next` | Next update | wiki-page-name | No |  | Page name of the next update, without `Update:`. | `Star Citizen Alpha 4.10.1` |  |
| `version` | Version | string | No |  | The version number. | `4.10.0` |  |
| `build` | Build | string | No |  | The build number from the release notes. | `4.10.0-LIVE.12519617` |  |
| `date` | Release date | date | No |  | The release date as `YYYY-MM-DD`; the estimated date while upcoming. | `2026-08-26` |  |
| `upcoming` | Upcoming | boolean | No | `no` | `yes` while the update is not yet released. | `yes` |  |
| `image` | Image | wiki-file-name | No |  | The update's page image, without `File:`. |  |  |
| `product` | Product | string | No | `Star Citizen` | What the update is for. | `Squadron 42` |  |

## Behavior

- A released Star Citizen update is filed in [Category:Patch notes](https://starcitizen.tools/Category:Patch_notes), an upcoming one in [Category:Upcoming patches](https://starcitizen.tools/Category:Upcoming_patches), and an update for any other product in `Category:<product> patch notes`.
- The previous and next links show the release date recorded on each neighbour's page, or "Unknown" when it has none. A neighbour's changed date appears here once this page is saved or purged.
- The short description reads "`<product>` build released on `<date>`" once a date is recorded, "scheduled for" instead while upcoming, or plain "`<product>` build" without a date.

## See also

- [Template:Patch list](https://starcitizen.tools/Template:Patch_list), the list of released updates built from these calls.
- [Module:Patch](https://starcitizen.tools/Module:Patch), the implementation.
