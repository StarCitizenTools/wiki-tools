# Template:Preload

Starter text for new articles, loaded into the editor by the create boxes on [Star Citizen Wiki:Create a new article](https://starcitizen.tools/Star_Citizen_Wiki:Create_a_new_article). Each subpage fits one kind of subject; this page is the one for everything else.

## Usage

Name the preload in an InputBox, or in a `preload=` URL parameter:

```wikitext
<inputbox>
type=create
preload=Template:Preload/Vehicle
</inputbox>
```

| Preload | Use for |
|---|---|
| `Template:Preload` | Any other topic, including lore organizations and species |
| `Template:Preload/Entity` | An in-game item or commodity the patch import missed |
| `Template:Preload/Vehicle` | A ship or ground vehicle, in the game or in concept |
| `Template:Preload/Location` | A system, planet, moon, landing zone or station |
| `Template:Preload/Company` | A company or manufacturer |
| `Template:Preload/Character` | A lore character |
| `Template:Preload/Developer` | Someone who works or worked at CIG |
| `Template:Preload/Guide` | A page in the `Guide:` namespace |

Player organization pages start from [Template:OrgPage](https://starcitizen.tools/Template:OrgPage) instead.

## Behavior

- `{{subst:PAGENAME}}` turns into the page title when the page is first saved. On a disambiguated title such as `ArcCorp (company)`, trim it by hand, above all in `{{Company}}`'s `name`, which the manufacturer lookup reads with no fallback.
- On a new Entity, Vehicle or Location page, the `{{Entity/…}}` sections stay empty until the page is purged or saved again: they read the UUID the infobox stored on the previous save.

## See also

- [Star Citizen Wiki:Create a new article](https://starcitizen.tools/Star_Citizen_Wiki:Create_a_new_article)
- [Template:Entity](https://starcitizen.tools/Template:Entity)
