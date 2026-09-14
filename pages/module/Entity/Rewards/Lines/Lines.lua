require('strict')

--- @module Entity/Rewards/Lines
--- Pure formatting for contract reward lines, shared by the render side
--- (Module:Entity/Rewards) and the `Rewards` structured-data property
--- (Module:Entity/Mission.getStructuredData). Requires nothing but strict, so
--- Mission (which stays out of the Data/Store require cycle) can use it too.

local p = {}

--- @param item table { amount, name }
--- @return string
function p.itemLine(item)
	return string.format('%dx [[%s]]', item.amount, item.name)
end

--- @param blueprint table { name }
--- @return string
function p.blueprintLine(blueprint)
	return string.format('[[%s]] blueprint', blueprint.name)
end

--- Reward-item lines (`itemLine`), then blueprint lines (`blueprintLine`),
--- in that order. A nil group list is empty.
--- @param rewardGroups table[]|nil
--- @param blueprintGroups table[]|nil
--- @return string[]
function p.rewardLines(rewardGroups, blueprintGroups)
	local lines = {}
	for _, group in ipairs(rewardGroups or {}) do
		for _, item in ipairs(group.items or {}) do
			table.insert(lines, p.itemLine(item))
		end
	end
	for _, group in ipairs(blueprintGroups or {}) do
		for _, blueprint in ipairs(group.items or {}) do
			table.insert(lines, p.blueprintLine(blueprint))
		end
	end
	return lines
end

return p
