# Template:Third-party logo

License tag for the logo of a community site or another third party, shown on the wiki only to identify that party's site. Use it under the license header of the logo's file page.

## Usage

Name the owner as the first positional argument.

```wikitext
=={{int:license-header}}==
{{Third-party logo|Erkul}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Owner | string | No | (its owner) | Who owns the logo, usually the site's name. | `Erkul` |

## Behavior

- Adds the file to [Category:Third-party logos](https://starcitizen.tools/Category:Third-party_logos).
- Marks the file as non-free and requiring attribution to the owner, in the machine-readable fields [Template:License card](https://starcitizen.tools/Template:License_card) emits.

## See also

- [Template:RSIlicense](https://starcitizen.tools/Template:RSIlicense), for Cloud Imperium's own logos and media.
