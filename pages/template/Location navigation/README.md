# Template:Location navigation

The navigation at the foot of a location page: what is inside the place, and what is on and around its planet or moon. Place it at the end of a location article, before `{{System map}}`.

## Usage

```wikitext
{{Location navigation}}
{{System map|Stanton}}
```

## Parameters

| Name | Type | Required | Default | Description | Example |
|---|---|---|---|---|---|
| `page` | wiki-page-name | No |  | Render the panels of another page instead of the current one. Only for documentation and previews. | `MicroTech (planet)` |

## Behavior

- **Inside panel.** It lists the places inside this one, such as the venues of a landing zone. On one of those places it lists its siblings.
- **Body panel.** It shows the nearest planet, moon or star, drawn as a distance gauge beside rows for its surface, what orbits it, its moons and its Lagrange stations. A moon's page shows the moon itself, and a star's page shows only what orbits the star directly; Moons and Lagrange rows exist for planets only.
- **Everything is listed.** Nothing is hidden or counted. The current page shows in bold.
- **Data comes from the pages' own infoboxes.** A place appears once its page has been saved with `{{Location}}`. A newly added place can take a few days to reach its siblings' panels, until their cache refreshes or they are purged.

## See also

- [Template:Location](https://starcitizen.tools/Template:Location)
- [Template:System map](https://starcitizen.tools/Template:System_map)
