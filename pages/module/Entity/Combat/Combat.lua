require('strict')

--- @module Entity/Combat
--- Renders a contract's combat spawn data: the headline hostile count plus one
--- row per spawn group. A sibling renderer like Module:Entity/Orders and
--- Module:Entity/Rewards -- it consumes Module:Entity/Data, so it shares
--- Apiunto's cache with any other Entity template on the page, and it stores
--- nothing.

local Data = require('Module:Entity/Data')
local TableLua = require('Module:TableLua')
local Lines = require('Module:Entity/Combat/Lines')
local emptyState = require('Module:Entity/EmptyState')

--- Builds the game-data class name to wiki page lookup the vehicle pool needs,
--- as ONE query for every vehicle the wiki has rather than one per ship, which
--- is cheap enough to sit well inside Bucket's per-query budget.
---
--- Narrowed to the vehicle subject types in the QUERY, not in Lua. The entity
--- bucket holds far more rows than any one query returns, so an unfiltered read
--- is silently truncated by the row limit and loses every vehicle past the cut.
---
--- Keyed lowercase because the two sources disagree on case for the same
--- identifier: the combat data gives `ORIG_85x` and `ARGO_Mole` where the pages
--- store `ORIG_85X` and `ARGO_MOLE`.
---
--- A class name absent from the result has no Bucket row, so the caller renders
--- that vehicle as plain text rather than guessing a title. The query is wrapped
--- because a Bucket infrastructure failure must not take the whole section down:
--- an empty map degrades every entry to plain text.
--- @return fun(className: string): string|nil Takes a LOWERCASED class name
local function buildPageResolver()
	local bucket = mw.ext.bucket
	local ok, rows = pcall(function()
		return bucket('entity')
			.select('page_name', 'class_name')
			.where(
				bucket.Or(
					{ 'subject_type', '=', 'Spacecraft' },
					{ 'subject_type', '=', 'Ground vehicle' },
					{ 'subject_type', '=', 'Grav-lev vehicle' }
				)
			)
			.limit(1000)
			.run()
	end)
	local byClassName = {}
	if ok and type(rows) == 'table' then
		for _, row in ipairs(rows) do
			if type(row.class_name) == 'string' and row.class_name ~= '' then
				byClassName[mw.ustring.lower(row.class_name)] = row.page_name
			end
		end
	end
	return function(className)
		return byClassName[className]
	end
end

--- The pool as a comma-joined list rather than a nested list, so a row stays as
--- short as its content allows. The whole pool renders: a reader checking
--- whether one specific ship can appear needs the complete list, and linking by
--- canonical page title is what keeps it readable.
--- @param row table a Lines.spawnRows entry
--- @return string
local function shipCell(row)
	if #row.ships == 0 then
		return '—'
	end
	return table.concat(row.ships, ', ')
end

--- @param rows table[] Lines.spawnRows output
--- @return string
local function renderSpawnTable(rows)
	local data = {}
	for _, row in ipairs(rows) do
		table.insert(data, {
			row.label,
			row.roleLabel,
			row.kind or '—',
			row.count or '—',
			shipCell(row),
		})
	end

	return tostring(TableLua.render({
		caption = 'Spawn groups',
		hideCaption = true,
		class = 'wikitable--fluid t-entity-combat-table',
		columns = {
			{ id = 'group', label = 'Group', textAlign = 'start' },
			{ id = 'role', label = 'Role', textAlign = 'start' },
			{ id = 'kind', label = 'Kind', textAlign = 'start' },
			{ id = 'count', label = 'Concurrent', textAlign = 'start' },
			{ id = 'ships', label = 'Possible vehicles', textAlign = 'start' },
		},
		data = data,
	}))
end

local p = {}

--- @param frame table
--- @return string
function p.main(frame)
	local args = Data.parseArgs(frame)
	local result = Data.get(args)

	if result.hasApiError then
		return emptyState.failed("Couldn't load combat encounters.")
	end

	local combat = result.apiData.combat
	if not Lines.hasData(combat) then
		return emptyState.none('No combat encounters.')
	end

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Combat/styles.css' },
	})

	local root = mw.html.create('div'):addClass('t-entity-combat')

	local total = Lines.totalEnemies(combat)
	if total then
		root:tag('p'):addClass('t-entity-combat-total'):wikitext('Hostiles: '):tag('strong'):wikitext(total)
	end

	local rows = Lines.spawnRows(combat, buildPageResolver())
	if #rows > 0 then
		root:wikitext(renderSpawnTable(rows))
	end

	return styles .. tostring(root)
end

return p
