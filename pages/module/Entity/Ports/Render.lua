require('strict')

--- @module Entity/Ports/Render
--- Wikitext generation for Entity/Ports. Consumes the `groups` array
--- produced by `pipeline.process()` and returns rendered wikitext.
---
--- Public API is a single entry point: `render.fromGroups(groups)`.
--- All render helpers are file-scoped locals — this module has no
--- `_internal` test hatch (render returns mw.html strings; not
--- meaningful to unit-test in isolation).
---
--- Render reads `agg.expandable` (pre-computed by Pipeline) instead
--- of inspecting `representative.category.expandIntoTypes`. This
--- keeps Render decoupled from Categories internals.

local Badge = require('Module:BadgeLua')
local CollapsibleCard = require('Module:CollapsibleCard')

local p = {}

--- Renders the size pill via Module:BadgeLua. When something is
--- equipped the pill shows the *equipped item's* size (more useful
--- than the port's accepted range — e.g. a S1–5 fuel mount with a
--- size-4 tank reads as "S4", not "S1–5"). For empty ports the pill
--- falls back to the port's size range. Success variant when
--- equipped; `--locked` modifier layers a stripe when the port is
--- hardware-locked.
---
--- @param node table  representative port node
--- @return string wikitext
local function renderPill(node)
	local sizeText
	if node.equippedItem and node.equippedItem.size then
		sizeText = 'S' .. tostring(node.equippedItem.size)
	elseif node.sizeMin == node.sizeMax then
		sizeText = 'S' .. tostring(node.sizeMin)
	else
		sizeText = 'S' .. tostring(node.sizeMin) .. '–' .. tostring(node.sizeMax)
	end
	local extraClass = 't-entity-ports-pill'
	if not node.editable then
		extraClass = extraClass .. ' t-entity-ports-pill--locked'
	end
	return Badge.render({
		text = sizeText,
		variant = node.equippedItem and 'success' or nil,
		class = extraClass,
	})
end

--- Strips a trailing space-separated index from a port displayName so
--- aggregated rows don't surface the first port's instance number
--- ("Spare Weapon Magazine 1" with count=8 reads as "Spare Weapon
--- Magazine"). Only applied when the result is non-empty; degenerate
--- inputs like "1" pass through unchanged.
---
--- @param name string|nil
--- @return string|nil
local function stripTrailingIndex(name)
	if type(name) ~= 'string' or name == '' then
		return name
	end
	local stripped = (name:gsub('%s+%d+$', ''))
	if stripped == '' then
		return name
	end
	return stripped
end

--- Returns the port's label: equipped item wikilink when present
--- (with fallback to plain name when the wikilink was suppressed
--- for a placeholder name), otherwise the port displayName.
---
--- When `count` > 1 AND we're falling back to displayName (the port is
--- empty), strip the trailing instance number — "Spare Weapon Magazine
--- 1" aggregated over 8 ports reads as "Spare Weapon Magazine", not
--- "Spare Weapon Magazine 1" with a confusing 8×. Solo rows keep their
--- index since each one is distinct.
---
--- @param node table  representative port node
--- @param count integer|nil  aggregated sibling count (1 if unset)
--- @return string  wikitext (may include [[link]])
local function renderLabel(node, count)
	if node.equippedItem then
		if node.equippedItem.pageLink and node.equippedItem.pageLink ~= '' then
			return node.equippedItem.pageLink
		end
		return node.equippedItem.name
	end
	if node.displayName and node.displayName ~= '' then
		if count and count > 1 then
			return stripTrailingIndex(node.displayName)
		end
		return node.displayName
	end
	return node.name or ''
end

--- Returns true when ANY aggregated node in the sibling group has
--- a count > 1. Drives the per-group decision to render the count
--- column for every row (so `1×` solo rows still get a count cell,
--- keeping the pills aligned) versus dropping the count column
--- entirely (so all-1× groups don't waste an indent slot on every row).
---
--- @param siblings table[]  aggregated nodes that share a parent
--- @return boolean
local function siblingsNeedCount(siblings)
	for _, s in ipairs(siblings) do
		if s.count > 1 then
			return true
		end
	end
	return false
end

--- Renders the head: optional count + size pill + label, wrapped
--- in an inline-flex `<span class="t-entity-ports-head">`. Shared
--- by both `renderRow` (parent rows) and `renderChildTree` (each
--- `<li>` in the tree) so spacing between count, pill, and label
--- is governed by a single flex `gap` rule and stays identical at
--- every depth.
---
--- When `showCount` is true the count cell renders for every row
--- in the group — including `01×` for solo rows — so pills line
--- up vertically. When false, the count cell is omitted and the
--- pill sits at the natural start.
---
--- A11y: the pad zero is `aria-hidden` (alignment, not data); solo
--- count cells are entirely `aria-hidden` (the "1×" is structural
--- filler); a visually-hidden "hardware-locked" suffix is appended
--- for non-editable ports since the visual stripe overlay is invisible
--- to AT.
---
--- @param agg table  aggregated port node
--- @param showCount boolean
--- @return string  wikitext
local function renderHead(agg, showCount)
	local rep = agg.representative
	local head = mw.html.create('span'):addClass('t-entity-ports-head')
	if showCount then
		-- Zero-pad single-digit counts ("01×", "04×") so columns of counts
		-- read as a uniform numeric block. The leading zero gets its own
		-- span so CSS can mute it. Solo rows (count=1) get a `--solo`
		-- modifier that mutes the whole cell — de-emphasizes the
		-- structural "01×" relative to the real counts above it.
		local cell = head:tag('span'):addClass('t-entity-ports-count')
		if agg.count == 1 then
			-- Solo cell is purely visual alignment; AT users get nothing
			-- meaningful from "1×". Hide the whole cell from AT instead of
			-- letting it leak into the row's read-aloud.
			cell:addClass('t-entity-ports-count--solo'):attr('aria-hidden', 'true')
		end
		if agg.count < 10 then
			cell:tag('span'):addClass('t-entity-ports-count__pad'):attr('aria-hidden', 'true'):wikitext('0')
		end
		cell:wikitext(tostring(agg.count) .. '×')
	end
	head:wikitext(renderPill(rep))
	-- Label wrapped in its own span so CSS can give it `min-width: 0`
	-- + `overflow-wrap: anywhere`, letting long unbreakable names like
	-- `RSI_Aurora_Mk2_Thruster_Main_Right` wrap inside the row on
	-- narrow viewports.
	head:tag('span'):addClass('t-entity-ports-label'):wikitext(renderLabel(rep, agg.count))
	if not rep.editable then
		-- The pill's `--locked` modifier draws a visual diagonal stripe;
		-- screen-reader users get nothing without this. Reads as a
		-- parenthetical after the label: "...VariPuck, hardware-locked".
		head:tag('span'):addClass('t-entity-ports-sr-only'):wikitext('hardware-locked')
	end
	return tostring(head)
end

--- Stamps the standard machine-readable + a11y data attrs on a row or
--- L-tree `<li>` element. Shared between `renderRow` and
--- `renderChildTree` so every port — top-level OR nested — is
--- self-describing for the future interactive topology gadget and any
--- other DOM scraper. Only emits attrs that have meaningful values
--- (skips equipped-name / equipped-uuid for empty ports).
---
--- @param node table  the underlying mw.html builder (row div or <li>)
--- @param agg table  aggregated port node
local function stampPortAttrs(node, agg)
	local rep = agg.representative
	node:attr('data-port-type', rep.type)
	node:attr('data-port-subtype', rep.subType)
	node:attr('data-port-size-min', tostring(rep.sizeMin))
	node:attr('data-port-size-max', tostring(rep.sizeMax))
	node:attr('data-port-count', tostring(agg.count))
	if rep.category and rep.category.label then
		node:attr('data-port-category', rep.category.label)
	end
	if rep.equippedItem and rep.equippedItem.name then
		node:attr('data-equipped-name', rep.equippedItem.name)
	end
	if rep._equippedUuid then
		node:attr('data-equipped-uuid', rep._equippedUuid)
	end
end

--- Recursively renders the child tree for an aggregated port.
--- Each child becomes an `<li>` containing the shared head; the
--- child's own sub-tree only nests further when its own
--- `expandable` flag is set. L-shaped connector lines are drawn
--- by CSS pseudo-elements on each `<li>`.
---
--- The count column decision is per sibling group: if any sibling
--- here has count > 1, all of them render their counts;
--- otherwise the count column is dropped for this group.
---
--- @param children table[]  aggregated child nodes
--- @return string  wikitext
local function renderChildTree(children)
	local ul = mw.html.create('ul'):addClass('t-entity-ports-tree')
	local showCount = siblingsNeedCount(children)
	for _, child in ipairs(children) do
		local li = ul:tag('li')
		-- Same data attrs as top-level rows so every port in the L-tree is
		-- self-describing to scrapers / the future topology gadget.
		stampPortAttrs(li, child)
		li:wikitext(renderHead(child, showCount))
		if child.expandable and #child.children > 0 then
			li:wikitext(renderChildTree(child.children))
		end
	end
	return tostring(ul)
end

--- Renders one aggregated row: shared head + recursive L-tree
--- when the port's category opts into expansion. Carries
--- forward-compat data attrs for the future interactive
--- topology gadget.
---
--- @param agg table  aggregated port node
--- @param showCount boolean
--- @return string  wikitext
local function renderRow(agg, showCount)
	local row = mw.html.create('div'):addClass('t-entity-ports-row')
	stampPortAttrs(row, agg)
	row:wikitext(renderHead(agg, showCount))
	if agg.expandable and #agg.children > 0 then
		row:wikitext(renderChildTree(agg.children))
	end
	return tostring(row)
end

--- Renders one category as a Module:CollapsibleCard. Primary
--- categories render open by default; the "Other" (collapsed) card
--- renders closed.
---
--- When `group.subGroups` is set (the "Other" card uses this),
--- the body is partitioned into per-label sub-sections, each with
--- its own `<div role="heading" aria-level="4">` sub-heading. The
--- reader can still see which collapsed bucket each row came from
--- after expanding the card. role=heading on a div (not an h-tag)
--- avoids polluting MediaWiki's TOC.
---
--- The count column decision is per sibling group: cards without
--- sub-groups compute it once; cards with sub-groups compute it
--- per sub-section.
---
--- @param group table  { label, order, collapsed, rows, subGroups? }
--- @return string  wikitext
local function renderCategory(group)
	local body = mw.html.create('div'):addClass('t-entity-ports-cat-body')
	if group.subGroups and #group.subGroups > 0 then
		for _, sub in ipairs(group.subGroups) do
			body:tag('div')
				:addClass('t-entity-ports-subcat')
				:attr('role', 'heading')
				:attr('aria-level', '4')
				:wikitext(sub.label)
			local showCount = siblingsNeedCount(sub.rows)
			for _, agg in ipairs(sub.rows) do
				body:wikitext(renderRow(agg, showCount))
			end
		end
	else
		local showCount = siblingsNeedCount(group.rows)
		for _, agg in ipairs(group.rows) do
			body:wikitext(renderRow(agg, showCount))
		end
	end
	return CollapsibleCard.render({
		title = group.label,
		content = tostring(body),
		open = not group.collapsed,
	})
end

--- Renders the full ports section: a vertical stack of category
--- cards, each containing one row per aggregated port group.
---
--- Wrapper carries `role="region"` + `aria-label="Port loadout"` so
--- AT users get a named landmark; the empty-state notice (rendered
--- by the coordinator, not here) intentionally skips the role since
--- it's a status message, not a region.
---
--- @param groups table[]  output of pipeline.process()
--- @return string  wikitext (does NOT include the templatestyles tag —
---                 the coordinator emits that)
function p.fromGroups(groups)
	local root =
		mw.html.create('div'):addClass('t-entity-ports'):attr('role', 'region'):attr('aria-label', 'Port loadout')
	for _, group in ipairs(groups) do
		root:wikitext(renderCategory(group))
	end
	return tostring(root)
end

return p
