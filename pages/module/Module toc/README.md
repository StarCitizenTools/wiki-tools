# Module:Module toc

Lists the functions a Lua module defines and the line each starts on.

[Module:Documentation](https://starcitizen.tools/Module:Documentation) requires it for the Function list table on module pages. Imported from [Module:Module toc](https://runescape.wiki/w/Module:Module_toc) on the RuneScape Wiki.

## For module editors

### API

- `functions(content) → { name, line }[]`: the functions the Lua source `content` declares with `function name(` or assigns with `name = function(`, in line order.
- `main() → string`: the same list for the current module, or the module a `/doc` documents, as a collapsed Function list table linking each function to its line.

### Gotchas

- It matches source text rather than parsing it. A declaration counts only after whitespace, and a function made any other way, such as one passed straight to a call or returned from another, is not listed.
- Comments are blanked before matching, and a `--[[ … ]]` block keeps its newlines, so the lines after it keep their numbers.
