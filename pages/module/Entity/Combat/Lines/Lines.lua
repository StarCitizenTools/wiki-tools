require('strict')

--- @module Entity/Combat/Lines
--- Pure formatting for a contract's combat spawn data, shared by the render side
--- (Module:Entity/Combat) and any structured-data consumer. Requires nothing but
--- strict, mirroring Module:Entity/Orders/Lines and Module:Entity/Rewards/Lines.

local p = {}

--- The four roles the API tags a spawn group with. Only `enemy` is adversarial;
--- `escort_target` and `defend_target` are the ship or NPC the contract protects,
--- and `other` is the untagged remainder. Rendering them in one undifferentiated
--- table would read as an enemy list, so the row carries its role label.
--- @type table<string, string>
p.ROLE_LABELS = {
	enemy = 'Hostile',
	escort_target = 'Escort target',
	defend_target = 'Defend target',
	other = 'Other',
}

--- Order the roles render in, hostiles first. A role absent from ROLE_LABELS
--- still renders, after these, under its own raw name.
--- @type string[]
p.ROLE_ORDER = { 'enemy', 'escort_target', 'defend_target', 'other' }

--- `'5'` for a fixed count, `'5 - 10'` for a range, nil when neither bound is
--- known. An equal or lower max collapses to the single figure rather than
--- rendering `'5 - 5'`.
--- @param min number|nil
--- @param max number|nil
--- @return string|nil
function p.countRange(min, max)
	if min == nil and max == nil then
		return nil
	end
	if min == nil then
		return tostring(max)
	end
	if max == nil or max <= min then
		return tostring(min)
	end
	return tostring(min) .. ' - ' .. tostring(max)
end

--- The game's internal spawn-group names carry their own count (`'Soldier x 2'`,
--- `'Juggernaut x 1 - Target'`), so they are shown verbatim: rewriting them
--- would desync the label from the `concurrent` numbers beside it.
--- @param spawn table aggregated_spawns entry
--- @return string
function p.groupLabel(spawn)
	local name = spawn.group_name
	if type(name) ~= 'string' or name == '' then
		return 'Unnamed group'
	end
	return name
end

--- `'Ship'` / `'Npc'` as the API spells it, or nil when unset. Kept raw rather
--- than prettified because it distinguishes a ship spawn (which carries both a
--- `ships` pool and `concurrent` bounds) from an on-foot one (which carries
--- neither -- every Npc group in the corpus has an empty pool and no bounds).
--- @param spawn table aggregated_spawns entry
--- @return string|nil
function p.spawnKind(spawn)
	local kind = spawn.spawn_kind
	if type(kind) ~= 'string' or kind == '' then
		return nil
	end
	return kind
end

--- The distinct vehicle names a spawn group can draw from, linked, in API
--- order. Duplicates are dropped: a group commonly lists two `class_name`
--- variants of one ship (`AEGS_Hammerhead_GS` and `AEGS_Hammerhead` both name
--- 'Aegis Hammerhead'), which would otherwise render the same link twice.
--- @param spawn table aggregated_spawns entry
--- @return string[]
function p.shipLinks(spawn)
	local links, seen = {}, {}
	for _, ship in ipairs(spawn.ships or {}) do
		local name = ship.name
		if type(name) == 'string' and name ~= '' and not seen[name] then
			seen[name] = true
			table.insert(links, '[[' .. name .. ']]')
		end
	end
	return links
end

--- One row per spawn group: role, label, kind, concurrent count and ship pool.
--- Groups are grouped by role in ROLE_ORDER, preserving API order within a role,
--- so the enemy groups a page is about lead the table.
--- @param combat table|nil the mission's `combat` object
--- @return { role: string, roleLabel: string, label: string, kind: string|nil, count: string|nil, ships: string[] }[]
function p.spawnRows(combat)
	local byRole = {}
	local roles = {}
	for _, spawn in ipairs((combat or {}).aggregated_spawns or {}) do
		local role = type(spawn.role) == 'string' and spawn.role or 'other'
		if not byRole[role] then
			byRole[role] = {}
			table.insert(roles, role)
		end
		table.insert(byRole[role], {
			role = role,
			roleLabel = p.ROLE_LABELS[role] or role,
			label = p.groupLabel(spawn),
			kind = p.spawnKind(spawn),
			count = p.countRange(spawn.concurrent_min, spawn.concurrent_max),
			ships = p.shipLinks(spawn),
		})
	end

	local rows = {}
	local emitted = {}
	for _, role in ipairs(p.ROLE_ORDER) do
		for _, row in ipairs(byRole[role] or {}) do
			table.insert(rows, row)
		end
		emitted[role] = true
	end
	for _, role in ipairs(roles) do
		if not emitted[role] then
			for _, row in ipairs(byRole[role]) do
				table.insert(rows, row)
			end
		end
	end
	return rows
end

--- The headline enemy count, from `combat.summary.total`. Distinct from the
--- per-group `concurrent` numbers: the total is how many hostiles the contract
--- spawns overall, which is the figure the infobox and the section lead quote.
--- @param combat table|nil the mission's `combat` object
--- @return string|nil
function p.totalEnemies(combat)
	local total = ((combat or {}).summary or {}).total
	if type(total) ~= 'table' then
		return nil
	end
	return p.countRange(total.min, total.max)
end

--- True when there is anything worth rendering: a total, or at least one spawn
--- group. `has_combat` alone is not enough — the API sets it on missions whose
--- `combat` object carries no summary and no spawns.
--- @param combat table|nil the mission's `combat` object
--- @return boolean
function p.hasData(combat)
	return p.totalEnemies(combat) ~= nil or #p.spawnRows(combat) > 0
end

return p
