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

local function renderEmpty(message)
	return tostring(mw.html.create('p'):addClass('t-entity-combat-empty'):wikitext(message))
end

--- The ship pool is the widest column by far (a patrol contract draws from 30+
--- ships), so it renders as a comma-joined list rather than a nested list: the
--- table already scrolls horizontally on a phone and a nested <ul> per row
--- would make every row as tall as the longest pool.
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

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Combat/styles.css' },
	})

	if result.hasApiError then
		return styles .. renderEmpty('Combat data unavailable.')
	end

	local combat = result.apiData.combat
	if not Lines.hasData(combat) then
		return styles .. renderEmpty('No combat encounters recorded for this contract.')
	end

	local root = mw.html.create('div'):addClass('t-entity-combat')

	local total = Lines.totalEnemies(combat)
	if total then
		root:tag('p'):addClass('t-entity-combat-total'):wikitext('Hostiles: '):tag('strong'):wikitext(total)
	end

	local rows = Lines.spawnRows(combat)
	if #rows > 0 then
		root:wikitext(renderSpawnTable(rows))
	end

	return styles .. tostring(root)
end

return p
