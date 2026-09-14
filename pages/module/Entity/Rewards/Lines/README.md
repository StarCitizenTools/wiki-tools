# Module:Entity/Rewards/Lines

Pure formatting for contract reward lines: awarded items, then blueprints, in the order the API returned them. It has no requires beyond `strict`, so it can be shared by both a render module and the Mission kind hook without creating a require cycle.

Required by [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards) (the visible items/blueprints tables) and [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission) (the `Rewards` structured-data property).
