# Template:Removed contract

Infobox for a contract that has been removed from ''Star Citizen''. Use it in place of [Template:Entity](https://starcitizen.tools/Template:Entity) on a contract the game no longer offers, so the article survives as a record of what the mission was.

## Usage

Replace `{{Contract}}` with this template and leave the parameters as they were. A contract that still exists in the game belongs on `{{Entity}}` instead, which reads its data live from the API.

```wikitext
{{Removed contract
| name = Kareah Sweep
| contractee = Crusader Security
| category = Verified
| type = Bounty Hunter
| pickup = Contract Manager
| reward = 21,000
| takes place = [[Stanton system]]
| orbit = [[Security Post Kareah]]
}}
```

State the removal in the article's first paragraph too. The banner marks the page, but a reader arriving at a section further down should not have to scroll up to learn it.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `name` | Name | string | Yes |  | Contract name as the game showed it. | `Kareah Sweep` |
| `image` | Image | wiki-file-name | No |  | Screenshot of the contract. | `Kareah.jpg` |
| `contractee` | Contractee | string | No |  | Who offered the contract. Shown as the infobox subtitle, and linked. | `Crusader Security` |
| `category` | Category | string | No |  | Whether the contract was legal. | `Verified` |
| `type` | Type | string | No |  | Contract type. Also drives the short description. | `Bounty Hunter` |
| `pickup` | Contract pickup | string | No |  | Where the contract was accepted. Linked. | `Contract Manager` |
| `shareable` | Shareable | string | No |  | Whether the contract could be shared with a party. | `Yes` |
| `season` | Available during | string | No |  | Event the contract ran during. Linked. | `Luminalia` |
| `reward` | aUEC reward | string | No |  | Payout in aUEC. | `21,000` |
| `reward items` | Item rewards | string | No |  | Items awarded on completion. | `1x Custodian SMG` |
| `unlock` | Unlocks | string | No |  | What completing the contract unlocked. | `[[ICC Assistance (2)]]` |
| `reputation` | Reputation | string | No |  | Reputation standing required. | `Tracker Trainee` |
| `requirement` | Required contract | string | No |  | Contract that had to be completed first. | `[[Above and Beyond]]` |
| `fee` | Fee | string | No |  | Up-front fee in aUEC. | `5,000` |
| `series` | Series | string | No |  | Contract series this belonged to. | `[[ICC Assistance (series)]]` |
| `previous` | Previous | string | No |  | Preceding contract in the series. Linked. | `ICC Assistance (1)` |
| `next` | Next | string | No |  | Following contract in the series. Linked. | `ICC Assistance (3)` |
| `takes place` | System | string | No |  | Star system the contract took place in. | `[[Stanton system]]` |
| `orbit` | Orbit | string | No |  | Body or station the contract took place at. | `[[Security Post Kareah]]` |

## Behavior

The banner at the top of the page and the tracking category both come from [Template:Removed](https://starcitizen.tools/Template:Removed), which this template transcludes; neither is repeated here. Pages land in [Category:Removed contracts](https://starcitizen.tools/Category:Removed_contracts), a subcategory of Removed content, and in no other category.

Nothing is recorded as queryable data: a removed contract has no game record to reconcile against, so listing it alongside live contracts would misrepresent what a reader can go and do.

There is deliberately no availability row. The template's own name answers that question, and a row repeating it invites an editor to set it to something else.

## See also

- [Template:Removed](https://starcitizen.tools/Template:Removed) for the banner, and for content other than contracts
- [Template:Entity](https://starcitizen.tools/Template:Entity) for a contract still in the game
- [Template:Faction contracts](https://starcitizen.tools/Template:Faction_contracts) to list a faction's live contracts
