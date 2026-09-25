# Template:Infobox commlink

Infobox for a page in the Comm-Link archive: the rehosting notice, a bar linking the previous and next Comm-Link of its series, and the Comm-Link's details. Use it once, at the top of every Comm-Link page.

## Usage

```wikitext
{{Infobox commlink
| title = Far From Home: Best Laid Plans
| url = https://robertsspaceindustries.com/comm-link/spectrum-dispatch/16835-Far-From-Home-Best-Laid-Plans
| image = Comm-Link-FarFromHomeFI4.jpg
| series = Far From Home
| type = Spectrum Dispatch
| publicationdate = 2018-11-07
}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `url` | Source URL | url | Yes |  | The URL of the Comm-Link on the RSI website. | `https://robertsspaceindustries.com/comm-link/spectrum-dispatch/16835-Far-From-Home-Best-Laid-Plans` |
| `title` | Title | string | Yes |  | The title of the Comm-Link. | `Far From Home: Best Laid Plans` |
| `image` | Image | wiki-file-name | No |  | The Comm-Link's cover image on the wiki, without `File:`. | `Comm-Link-FarFromHomeFI4.jpg` |
| `series` | Series | string | No |  | The series the Comm-Link belongs to. | `Far From Home` |
| `type` | Type | string | Yes |  | The Comm-Link type. | `Transmission` |
| `publicationdate` | Publication date | date | Yes |  | The publication date as `YYYY-MM-DD`. | `2018-11-07` |

## Behavior

- The page is filed in `Category:Comm-Link`, in the category of its `type`, and in the category of its `series`.
- A bar above the infobox links the previous and next Comm-Link of the series, ordered by publication date and then by the number in `url`, around the series name linked to its category. The first Comm-Link of a series has no previous one and the latest has no next.
- A publication date with no year-month-day date in it (`January 2015`) places the Comm-Link after every dated one in its series.
- After creating a Comm-Link, or changing its date or series, purge the Comm-Links on either side of it, in its old series too when the series changed, so that their links follow.
- Empty fields are left out of the infobox. Without an image, the infobox shows a placeholder with an upload button.
- The rehosting notice links the original Comm-Link only when `url` is set.

## See also

- [Template:Comm-Link list](https://starcitizen.tools/Template:Comm-Link_list), which lists Comm-Links by series or type.
- [Module:CommLink](https://starcitizen.tools/Module:CommLink), the implementation of the notice, bar, infobox, categories and SEO metadata.
