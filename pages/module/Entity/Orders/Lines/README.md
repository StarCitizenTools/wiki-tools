# Module:Entity/Orders/Lines

Pure formatting for hauling-contract order lines: quantity plus cargo/package/item name, in the order the API returned them. It has no requires beyond `strict`, so it can be shared by both a render module and the Mission kind hook without creating a require cycle.

Required by [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders) (the visible orders table) and [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission) (the `Orders` structured-data property).

## For module editors

### Gotchas

- An order can carry only a uuid and no name (146 of them in the 4.10 corpus, nearly all kind `MissionItem`): an item the mission defines that the catalogue does not name. `cargoLabel` returns `Mission item` for those. Concatenating the nil name previously script-errored the whole Orders table, on any page that reached such an order.
