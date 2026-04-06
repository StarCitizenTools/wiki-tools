require('strict')

local p = {}

--- Stores structured data as SMW properties on the current page.
--- Silently handles failures — callers should check the return value.
---
--- @param data table<string, any> Flat key-value table of property names to values
--- @return boolean success True if storage succeeded
--- @return string|nil error Error message if storage failed
local PROPERTY_PREFIX = 'entity_test_'

function p.store(data)
	local prefixed = {}
	for k, v in pairs(data) do
		prefixed[PROPERTY_PREFIX .. k] = v
	end

	local success, err = pcall(mw.smw.set, prefixed)
	if not success then
		return false, 'SMW storage failed: ' .. tostring(err)
	end
	return true
end

return p
