# Template:Faction contracts

Lists every contract a faction offers, as an interactive browse table. Use it on a faction, company or contractor page in place of hand-maintaining a contract list.

## Usage

On a page whose title is exactly the faction name as the contracts record it, no argument is needed:

```wikitext
{{Faction contracts}}
```

Where the page title and the recorded faction name differ, name the faction. This is the common case for a company whose article title spells an ampersand out:

```wikitext
{{Faction contracts|Rough & Ready}}
```

## Parameters

| Parameter | Description |
|---|---|
| `1` / `faction` | Faction name to match, exactly as the contract pages record it. Defaults to the page name. |
| `columns` | Replaces the default column set. Same grammar as [Template:Data table](https://starcitizen.tools/Template:Data_table)'s `columns`. |

## Behavior

The table is built from the contracts' own stored data, so it needs no upkeep: a new contract page appears once it is saved, and a contract whose faction changes moves tables on its own.

Only contracts that carry game data are listed. A contract removed from the game keeps its article but stores nothing, so it does not appear here, and neither does a page that documents a type of contract rather than one specific contract.

A faction whose name is spelled differently on the contract pages than in the argument produces an empty table rather than an error, so check a known contract's Faction value before assuming there are none.

## See also

- [Template:Data table](https://starcitizen.tools/Template:Data_table) for the general browse table
- [List of contracts](https://starcitizen.tools/List_of_contracts) for every contract at once
