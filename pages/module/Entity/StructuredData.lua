require('strict')

local p = {}

--- Returns the property prefix for the current page's namespace.
--- Main namespace uses no prefix (canonical storage). Other namespaces
--- are prefixed with their namespace text (e.g. "template_", "user_") so
--- test and template pages don't pollute canonical SMW queries.
---
--- @return string
local function getPrefix()
	local nsText = mw.title.getCurrentTitle().nsText
	if nsText == '' then
		return ''
	end
	return nsText:lower():gsub(' ', '_') .. '_'
end

--- Stores structured data as SMW properties on the current page.
--- Silently handles failures — callers should check the return value.
---
--- @param data table<string, any> Flat key-value table of property names to values
--- @return boolean success True if storage succeeded
--- @return string|nil error Error message if storage failed
function p.store(data)
	local prefix = getPrefix()
	local prefixed = {}
	for k, v in pairs(data) do
		prefixed[prefix .. k] = v
	end

	local success, err = pcall(mw.smw.set, prefixed)
	if not success then
		return false, 'SMW storage failed: ' .. tostring(err)
	end
	return true
end

return p
