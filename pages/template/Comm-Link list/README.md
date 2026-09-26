# Template:Comm-Link list

Lists Comm-Links from the Comm-Link archive with their series, type and publication date, newest first. Use it on a series or type page to list its Comm-Links.

## Usage

```wikitext
{{Comm-Link list|series=Galactic Guide}}
{{Comm-Link list|series=Kaizen|type=Spectrum Dispatch}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `series` | Series | string | No |  | Only Comm-Links of this series. | `Galactic Guide` |
| `type` | Type | string | No |  | Only Comm-Links of this type. | `Transmission` |

## Behavior

- With neither parameter, every Comm-Link is listed.
- Each row comes from a Comm-Link page's `{{CommLink}}`. A new Comm-Link appears once this page is next parsed; purge it to list the Comm-Link at once.
- Series and Type have checkbox filters, and Published sorts and filters as a date.

## See also

- [Template:CommLink](https://starcitizen.tools/Template:CommLink), which records each Comm-Link.
- [Module:CommLink](https://starcitizen.tools/Module:CommLink), the implementation.
