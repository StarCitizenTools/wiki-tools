# Template:Vehicle

Renders a vehicle's infobox through Module:Entity, the same engine that powers Template:Entity. `{{Vehicle}}` is the recommended entry point for ship and ground-vehicle pages: the invocation is identical to `{{Entity}}`, but the editing form lists only the parameters that apply to vehicles, so you are not wading through item or weapon fields that a vehicle never uses. For an in-game vehicle, supply the entity UUID (or let it fall back to the UUID already stored on the page) and the infobox fills itself from the live API. The curated and editorial parameters below are for overriding a wrong API value or for documenting concept and unreleased ships that have no in-game record yet.

## Usage

In-game vehicle, everything from the API. The UUID can be omitted if `{{Vehicle}}` or `{{Entity}}` was invoked earlier on the page (it falls back to the UUID stored on the page):

```wikitext
{{Vehicle|uuid=08a5bfdb-1972-421f-83fe-be03b7ac5222}}
```

In-game vehicle with a couple of curated overrides and external links:

```wikitext
{{Vehicle
| uuid            = 08a5bfdb-1972-421f-83fe-be03b7ac5222
| size            = Large
| career          = Transport
| pledgeurl       = https://robertsspaceindustries.com/pledge/ships/...
| brochureurl     = https://example.com/brochure-a; https://example.com/brochure-b
| whitleysguideurl = https://example.com/whitleys-guide
}}
```

Concept or unreleased ship with no in-game record. Declare the page as a planned vehicle with `kind`, pick the family, and supply the stats by hand:

```wikitext
{{Vehicle
| kind          = Vehicle
| family        = ship
| manufacturer  = AEGS
| size          = Medium
| maxcrew       = 2
| scmspeed      = 215
| maxspeed      = 1100
| cargocapacity = 12
| pledgecost    = 175
| productionstate = In concept
| conceptdate   = 2024-10-18
}}
```

## Parameters

<!-- templatedata: format=block -->
<!-- templatedata: suggestedvalues kind = Vehicle -->
<!-- templatedata: suggestedvalues family = ship; ground; gravlev -->
<!-- templatedata: suggestedvalues size = Small; Medium; Large; Capital -->
<!-- templatedata: suggestedvalues career = Combat; Transport; Exploration; Industrial; Support; Competition; Ground; Multi-role -->
<!-- templatedata: suggestedvalues productionstate = Flight ready; In production; Active production; Active for Squadron 42; Long term production; In concept; Lore-only; Unconfirmed -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the UUID stored on the current page) | In-game entity UUID. If omitted, defaults to the UUID stored on the page by a prior {{Vehicle}}/{{Entity}} invocation. Required for an in-game vehicle if nothing has set the stored UUID yet. | `08a5bfdb-1972-421f-83fe-be03b7ac5222` |
| `name` | Name | string | No | (API name) | Display-name override for the infobox title. | `Constellation Andromeda` |
| `image` | Image | wiki-file-name | No |  | Infobox image, as a file name on the wiki (no `File:` prefix). Overrides the image otherwise resolved for the page. | `Gladius.jpg` |
| `kind` | Kind | string | No |  | Declares the page as a planned/concept vehicle when there is no in-game record (no UUID). Set to `Vehicle`. Leave blank for live in-game vehicles. | `Vehicle` |
| `family` | Family | string | No | (derived from the API) | Vehicle family for concept/editorial pages without a UUID: one of `ship`, `ground`, or `gravlev`. In-game vehicles derive this automatically and ignore the value. | `ship` |
| `role` | Role | string | No | (API value) | Role override (curated taxonomy). The wiki value wins over the API in the short description, the infobox Role row, and the stored Role property. | `Heavy fighter` |
| `career` | Career | string | No | (API value) | Career override (curated taxonomy). The wiki value wins over the API. | `Transport` |
| `size` | Size | string | No | (API value) | Ship-matrix size name: one of `Small`, `Medium`, `Large`, or `Capital`. Wins over the API size when both exist. | `Large` |
| `manufacturer` | Manufacturer | string | No | (API value) | Manufacturer override, as a manufacturer code (e.g. `AEGS`) or a full name. Wins over the API. | `AEGS` |
| `canBuy` | Can buy | boolean | No | (inferred from UEX purchase data) | Override for the "Buy" flag in the acquisition summary. Set to `no` when UEX has stale prices for a vehicle that has been removed from shops. | `no` |
| `canRent` | Can rent | boolean | No | (inferred from UEX rental data) | Override for the "Rent" flag in the acquisition summary. | `yes` |
| `canPledge` | Can pledge | boolean | No | (inferred from the presence of a pledge price) | Override for the "Pledge" flag in the acquisition summary. | `yes` |
| `pledgeurl` | Pledge URL | url | No | (API value) | RSI pledge-store URL for the vehicle. | `https://robertsspaceindustries.com/pledge/ships/...` |
| `galactapediaurl` | Galactapedia URL | url | No |  | Galactapedia article URL for the vehicle. | `https://robertsspaceindustries.com/galactapedia/article/...` |
| `brochureurl` | Brochure URL | url | No |  | Brochure URL(s). Accepts a `;`-separated list for multiple links. | `https://example.com/brochure` |
| `trailerurl` | Trailer URL | url | No |  | Trailer/video URL(s). Accepts a `;`-separated list for multiple links. | `https://youtu.be/...` |
| `presentationurl` | Presentation URL | url | No |  | Presentation/commercial URL(s). Accepts a `;`-separated list for multiple links. | `https://example.com/presentation` |
| `qaurl` | Q&A URL | url | No |  | Q&A post URL(s). Accepts a `;`-separated list for multiple links. | `https://robertsspaceindustries.com/comm-link/...` |
| `whitleysguideurl` | Whitley's Guide URL | url | No |  | Whitley's Guide entry URL(s). Accepts a `;`-separated list for multiple links. | `https://example.com/whitleys-guide` |
| `scmspeed` | SCM speed | number | No | (API value) | SCM (Space Combat Maneuvering) speed, in m/s. (concept/unreleased ships; in-game ships use the API value) | `215` |
| `maxspeed` | Max speed | number | No | (API value) | Maximum speed, in m/s. (concept/unreleased ships; in-game ships use the API value) | `1100` |
| `mincrew` | Minimum crew | number | No | (API value) | Minimum crew. (concept/unreleased ships; in-game ships use the API value) | `1` |
| `maxcrew` | Maximum crew | number | No | (API value) | Maximum crew. (concept/unreleased ships; in-game ships use the API value) | `4` |
| `cargocapacity` | Cargo capacity | number | No | (API value) | Cargo capacity, in SCU. (concept/unreleased ships; in-game ships use the API value) | `46` |
| `mass` | Mass | number | No | (API value) | Mass, in kg. (concept/unreleased ships; in-game ships use the API value) | `224500` |
| `length` | Length | number | No | (API value) | Overall length, in metres. (concept/unreleased ships; in-game ships use the API value) | `92` |
| `width` | Width | number | No | (API value) | Overall width, in metres. (concept/unreleased ships; in-game ships use the API value) | `28` |
| `height` | Height | number | No | (API value) | Overall height, in metres. (concept/unreleased ships; in-game ships use the API value) | `14` |
| `retractedlength` | Retracted length | number | No |  | Length with landing gear and wings retracted, in metres. Editorial only (the API does not model retracted dimensions). | `90` |
| `retractedwidth` | Retracted width | number | No |  | Width with landing gear and wings retracted, in metres. Editorial only (the API does not model retracted dimensions). | `22` |
| `retractedheight` | Retracted height | number | No |  | Height with landing gear and wings retracted, in metres. Editorial only (the API does not model retracted dimensions). | `12` |
| `pledgecost` | Pledge price | number | No | (API value) | Standalone pledge (store) price, in USD. (concept/unreleased ships; in-game ships use the API value) | `260` |
| `warbondcost` | Warbond price | number | No |  | Warbond pledge price, in USD (discounted, limited-stock). Editorial only. | `240` |
| `originalpledgecost` | Original pledge price | number | No |  | Original standalone pledge price, in USD; shown as "was $M" when it differs from the current price. Editorial only. | `225` |
| `originalwarbondcost` | Original warbond price | number | No |  | Original warbond pledge price, in USD. Editorial only. | `200` |
| `pledgeavailability` | Pledge availability | string | No |  | Free-text pledge-availability note. Editorial only. | `Limited` |
| `productionstate` | Production state | string | No | (API value) | Production status: one of `Flight ready`, `In production`, `Active production`, `Active for Squadron 42`, `Long term production`, `In concept`, `Lore-only`, `Unconfirmed`. (concept/unreleased ships; in-game ships use the API value) | `In concept` |
| `addedinversion` | Added in version | string | No |  | Game update the vehicle became flight ready (e.g. `Alpha 4.8.0`); rendered as the "Flight ready in" row in the Development section and stored as the `Added in version` SMW property (the canonical `Update:` page). Editorial only. | `Alpha 4.8.0` |
| `productionstatenote` | Production state note | string | No |  | Free-text production note shown in the Development section (e.g. rework status). Display-only, not stored in SMW. Editorial only. | `Rework in progress` |
| `series` | Series | string | No |  | Series/model grouping (the "Model" row). Alias: `model`. Editorial only. | `Constellation` |
| `generation` | Generation | string | No |  | Generation/mark within the series. Aliases: `Generation`, `mark`. Editorial only. | `Mk IV` |
| `releasedate` | Release date | string | No |  | In-game release date. Editorial only. | `2014-12-19` |
| `retiredate` | Retirement date | string | No |  | Retirement date (removed from sale or game). Editorial only. | `2018-11-30` |
| `conceptdate` | Concept announcement date | string | No |  | Date the concept was announced. Editorial only. | `2012-11-26` |
| `saledate` | Concept sale date | string | No |  | Date of the concept sale. Editorial only. | `2012-11-26` |

## Behavior

- `{{Vehicle}}` is a pure passthrough to Module:Entity, byte-identical to `{{Entity}}` in what it invokes. The only difference is the TemplateData below, which scopes the editing form to vehicle parameters. Because it injects no `kind` default, a live page that relies on its stored UUID keeps reading that UUID exactly as it does under `{{Entity}}`.
- For an in-game vehicle the infobox pulls its stats from the API. The editorial/planned parameters (speeds, crew, cargo, mass, dimensions, prices, production state, dates) are primarily for concept and unreleased ships; where the same value also exists in the API, the wikitext value overrides the API value.
- A page with no in-game record (a concept or unreleased ship) is declared planned with `kind=Vehicle`; its family then comes from `family=` (`ship`, `ground`, or `gravlev`) and every stat is supplied by hand.
- The multi-value URL parameters (`brochureurl`, `trailerurl`, `presentationurl`, `qaurl`, `whitleysguideurl`) each accept a `;`-separated list to register more than one link.
