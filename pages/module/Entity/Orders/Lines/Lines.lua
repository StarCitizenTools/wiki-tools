require('strict')

--- @module Entity/Orders/Lines
--- Pure formatting for hauling-contract order lines, shared by the render side
--- (Module:Entity/Orders) and the `Orders` structured-data property
--- (Module:Entity/Mission.getStructuredData). Requires nothing but strict, so
--- Mission (which stays out of the Data/Store require cycle) can use it too.

local p = {}

--- @param item table hauling-order entry
--- @return string quantity display text
--- @return number units
--- @return number scu
function p.formatQuantity(item)
	if item.min_scu then
		return tostring(item.min_scu) .. ' SCU', 0, item.min_scu
	end
	if item.min_amount or item.max_amount then
		return tostring(item.min_amount or item.max_amount) .. 'x', item.min_amount or item.max_amount, 0
	end
	return '?', 0, 0
end

--- The cargo label for one hauling order: `'Cargo'` when a `TagMatch` order
--- names a container size, `'Package'` for any other `TagMatch`, else the
--- requested item's own name, linked. The one definition the stored `Orders`
--- property and the rendered table both depend on.
--- @param order table hauling-order entry
--- @return string
function p.cargoLabel(order)
	if order.kind == 'TagMatch' then
		return order.max_container_size and 'Cargo' or 'Package'
	end
	-- 146 orders in the 4.10 corpus carry only a uuid and no name (nearly all
	-- kind 'MissionItem'): an item the mission defines that the catalogue does
	-- not name. Concatenating the nil took the whole Orders table down with a
	-- script error.
	if type(order.name) ~= 'string' or order.name == '' then
		return 'Mission item'
	end
	return '[[' .. order.name .. ']]'
end

--- One `'<quantity> <cargo>'` line per hauling order, in order.
--- @param haulingOrders table[]|nil
--- @return string[]
function p.orderLines(haulingOrders)
	local lines = {}
	for _, order in ipairs(haulingOrders or {}) do
		local quantity = p.formatQuantity(order)
		table.insert(lines, string.format('%s %s', quantity, p.cargoLabel(order)))
	end
	return lines
end

return p
