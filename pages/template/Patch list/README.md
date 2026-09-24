# Template:Patch list

Lists every Star Citizen update with its status, build and release date, upcoming updates first. Place it once, on [Patch notes](https://starcitizen.tools/Patch_notes).

## Usage

```wikitext
{{Patch list}}
```

## Parameters

This template takes no parameters.

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|

## Behavior

- Each row comes from an update page's `{{Patch}}` call, with the build and date it records. A newly saved update appears once this page is next parsed; purge it to list the update at once.
- Upcoming updates list first, then released updates newest first.
- Updates for other products are left out.

## See also

- [Template:Patch](https://starcitizen.tools/Template:Patch), which records each update.
- [Module:Patch](https://starcitizen.tools/Module:Patch), the implementation.
