# Module:Module toc

Lists the functions a Lua module defines and the line each starts on.

[Module:Dependencies](https://starcitizen.tools/Module:Dependencies) requires it for the Functions row of the Technical details panel.

## For module editors

### API

- `functions(content) → { name, line }[]`: the functions the Lua source `content` declares with `function name(` or assigns with `name = function(`, in line order.

### Gotchas

- It matches source text rather than parsing it. A declaration counts only after whitespace, and a function made any other way, such as one passed straight to a call or returned from another, is not listed.
- Comments are blanked before matching, and a `--[[ … ]]` block keeps its newlines, so the lines after it keep their numbers.
