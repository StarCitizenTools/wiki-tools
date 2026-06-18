require('strict')

local iconText = require('Module:IconText')

local p = {}

local lang = mw.language.getContentLanguage()

--- Render the UEC glyph followed by pre-formatted amount text, with the
--- module's TemplateStyles attached.
---
--- @param amountText string
--- @return string
local function renderUec(amountText)
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:UEC/styles.css' },
	})

	return styles
		.. iconText._main({
			icon = 'Sc-icon-uec.svg',
			iconTitle = 'UEC',
			text = amountText,
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

--- Render a single UEC value: the glyph followed by the grouped number.
---
--- @param uec string|number
--- @return string
function p._main(uec)
	local uecNum = tonumber(uec)

	if not uecNum then
		error('Invalid UEC value: ' .. tostring(uec))
	end

	return renderUec(lang:formatNum(uecNum))
end

--- Render a UEC range: the glyph followed by "min–max" (grouped), collapsing
--- to a single value when min == max. Both bounds must be numeric.
---
--- @param min string|number
--- @param max string|number
--- @return string
function p._range(min, max)
	local minNum = tonumber(min)
	local maxNum = tonumber(max)

	if not minNum or not maxNum then
		error('Invalid UEC range: ' .. tostring(min) .. '–' .. tostring(max))
	end

	if minNum == maxNum then
		return renderUec(lang:formatNum(minNum))
	end

	return renderUec(lang:formatNum(minNum) .. '–' .. lang:formatNum(maxNum))
end

return p
