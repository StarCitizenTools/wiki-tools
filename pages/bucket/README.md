# Bucket schemas

Generated Bucket schema pages, one per table, mirroring `Bucket:<Name>` on the wiki (namespace 9592, json content model). Never edit these by hand: run `mise run bucket:schemas` after changing `Module:Entity/properties.json`, `Module:Company/properties.json`, or `Module:WearableSet/properties.json`, and `mise run lint` fails while they are stale.

A schema page is a JSON object keyed by field name; each value is `{"type", "index", "repeated"}` as [Extension:Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) reads it. The page title is the bucket name with underscores as spaces and the first letter capitalised (`Bucket:Vehicle stats` is queried as `vehicle_stats`).

A bucket may be defined by more than one manifest (`entity` is defined by `Module:Entity/properties.json`, `Module:Company/properties.json`, and `Module:WearableSet/properties.json`): their fields are merged into one schema, and a field two or more manifests define must agree on type, index and repeated, or the build fails naming the bucket and field.

Deploying a schema page creates or alters the table: adding a field is non-destructive, deleting the page drops the table. The deploying account needs the `editbucket` right.
