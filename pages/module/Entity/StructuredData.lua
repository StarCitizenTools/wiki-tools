require('strict')

local p = {}

--- Stores structured data as SMW properties on the current page.
--- Silently handles failures — callers should check the return value.
---
--- @param data table<string, any> Flat key-value table of property names to values
--- @return boolean success True if storage succeeded
--- @return string|nil error Error message if storage failed
function p.store(data)
	local success, err = pcall(mw.smw.set, data)
	if not success then
		return false, 'SMW storage failed: ' .. tostring(err)
	end
	return true
end

return p
