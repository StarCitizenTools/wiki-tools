require('strict')

local iconText = require('Module:IconText')

local p = {}

--- Render the UEC text
---
--- @param uecNum number
--- @return string
local function renderUec(uecNum)
	local lang = mw.language.getContentLanguage()

	return iconText._main({
		icon = 'Sc-icon-uec.svg',
		iconTitle = 'UEC',
		text = lang:formatNum(uecNum),
		class = 't-uec',
		mask = true,
	})
end

--- Wikitext entry point for the module
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	return p._main(getArgs(frame)[1])
end

--- Render the UEC text
---
--- @param uec string|number
--- @return string
function p._main(uec)
	local uecNum = tonumber(uec)

	if not uecNum then
		error('Invalid UEC value: ' .. tostring(uec))
	end

	return renderUec(uecNum)
end

return p
