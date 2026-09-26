# commlinks

Plans the pages of one RSI Comm-Link series that the wiki is missing (today the monthly reports). See [`../../README.md`](../../README.md) for how tools run; this file covers what this one decides and why.

## What it plans

- **Discovery** is RSI's own series listing (`series` in `config.json`) plus the Star Citizen Wiki API's title search (`titleQuery`, kept when `titlePattern` matches). Neither source is complete on its own: a report that either source finds is a candidate, and `plan.json` lists under `discoveryDisagreements` every report only one source found. A candidate is missing when no page's `{{CommLink}}` `url` carries its RSI number (the `comm_link` Bucket table).
- **Body text** comes from RSI's HTML: the classic layout to October 2021, and from then a Vue shell whose body is a separate fragment named by `const s3Url`. The API's plain text is only the check: every API line must appear in the generated page. Two API artefacts pass on their own: a line the API glues across page blocks in page order (a paragraph run into the sign-off past the Conclusion title and an image), and a line made up only of pieces of the page's image credits (an intro such as "Image by" and a name), which the API runs together without spaces. `fidelityIgnore` lists the other accepted API lines.
- **Dates** come, in order, from RSI's series listing, whose `Posted:` value is the publication time for older items (`dateSource: "rsi"`; recent items show only an age such as "3 weeks ago"); else the API's `created_at`, unless it is one of `apiIngestDates` (days the API imported reports in bulk) or later than the first Wayback Machine capture of the RSI page (`"api"`); else that capture's UTC day (`"wayback"`). RSI's own `Date:` field on the page shows the day it is fetched, so it is never used.
- **Images** are hashed, not stored (`cache.json`, keyed by URL). An image whose SHA1 the wiki already holds, or that another planned page already uploads, is reused; the rest are named `<page> - NN.<ext>` with the extension of the sniffed type. An image RSI answers with 404 is left out of the page and listed under the page's `missingImages`.
- **Links** go to the first case-exact mention per section of a title in `linkCategories`, or of an `aliases` term, skipping disambiguation pages, the `stoplist`, a title with a parenthetical, a title under four characters, and single words the reports also use in lower case. A term never links inside a mention of a longer term, so an alias such as `Hurston Dynamics` keeps `Hurston` from linking the planet there.

## Review reasons

| Reason | Meaning |
|---|---|
| `fetch-or-parse` | RSI's page or fragment could not be fetched, or its layout was not recognised |
| `title-exists` | the page name is taken by a page that stores a different RSI number |
| `no-date` | neither RSI's listing, the API nor the Wayback Machine dates the report, or the Wayback lookup failed |
| `images` | an image could not be downloaded (other than a 404), or is not an image |
| `fidelity` | API text lines are missing from the page; `detail` lists them |

Accept a review entry for good by adding its id to `knownReview`, which keeps it out of `-diff`'s exit status.
