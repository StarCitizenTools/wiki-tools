# commlinks

Plans the pages of one RSI Comm-Link series that the wiki is missing (today the monthly reports). See [`../../README.md`](../../README.md) for how tools run; this file covers what this one decides and why.

## What it plans

- **Discovery** is RSI's own series listing (`series` in `config.json`) plus the Star Citizen Wiki API's title search (`titleQuery`, kept when `titlePattern` matches). Neither source is complete on its own: a report that either source finds is a candidate, and `plan.json` lists under `discoveryDisagreements` every report only one source found. A candidate is missing when no page's `{{CommLink}}` `url` carries its RSI number (the `comm_link` Bucket table).
- **Body text** comes from RSI's HTML: the classic layout to October 2021, and from then a Vue shell whose body is a separate fragment named by `const s3Url`. The API's plain text is only the check: every API line must appear in the generated page (`fidelityIgnore` lists accepted API artefacts).
- **Dates** are the API's `created_at` when the first Wayback Machine capture of the RSI page falls within three days after it, otherwise the capture's day (`dateSource: "wayback"`). The API date is an ingest date for many reports, and RSI's own `Date:` field shows the day it is fetched.
- **Images** are hashed, not stored (`cache.json`, keyed by URL). An image whose SHA1 the wiki already holds, or that another planned page already uploads, is reused; the rest are named `<page> - NN.<ext>` with the extension of the sniffed type. An image RSI answers with 404 is left out of the page and listed under the page's `missingImages`.
- **Links** go to the first case-exact mention per section of a title in `linkCategories`, or of an `aliases` term, skipping disambiguation pages, the `stoplist`, a title with a parenthetical, a title under four characters, and single words the reports also use in lower case.

## Review reasons

| Reason | Meaning |
|---|---|
| `fetch-or-parse` | RSI's page or fragment could not be fetched, or its layout was not recognised |
| `title-exists` | the page name is taken by a page that stores a different RSI number |
| `no-wayback-capture` | there is no capture to date the report by |
| `images` | an image could not be downloaded (other than a 404), or is not an image |
| `fidelity` | API text lines are missing from the page; `detail` lists them |

Accept a review entry for good by adding its id to `knownReview`, which keeps it out of `-diff`'s exit status.
