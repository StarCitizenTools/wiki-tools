require('strict')

--- @module Entity/LocationNavigation
--- Backs {{Location navigation}}: the page foot's Inside panel (the place's
--- contents, or its siblings when it sits inside another place) and Body panel
--- (the nearest body's surroundings). {{System map}} follows it on the page.

local data = require('Module:Entity/LocationNavigation/Data')
local model = require('Module:Entity/LocationNavigation/Model')
local render = require('Module:Entity/LocationNavigation/Render')

local p = {}

local STYLES = 'Module:Entity/LocationNavigation/styles.css'

--- Both panels for `subject`, or '' when neither has anything to show.
--- @param subject string
--- @return string
function p.render(subject)
	local context = data.context(subject)
	local out = {}
	local isBody = context.body ~= nil and context.body.entry.page == subject
	if not isBody then
		local container = context.zone == 'inside' and context.parent or subject
		if type(container) == 'string' then
			local panel = model.insidePanel(container, data.children(container), context.body)
			if panel then
				out[#out + 1] = render.insidePanel(panel)
			end
		end
	end
	if context.body then
		local panel = model.bodyPanel(context.body, data.children(context.body.entry.page) or {})
		if panel then
			out[#out + 1] = render.bodyPanel(panel)
		end
	end
	return table.concat(out)
end

--- `page` normalised to its main-namespace title text ("microTech (planet)"
--- finds "MicroTech (planet)"), or nil when it names no main-namespace page.
--- @param page string|nil
--- @return string|nil
local function normalisePage(page)
	if type(page) ~= 'string' then
		return nil
	end
	local title = mw.title.new(page)
	if not title or title.namespace ~= 0 then
		return nil
	end
	return title.text
end

--- Wikitext entry point. |page= renders the panels of another page, for
--- documentation and previews; without it only a main-namespace page renders.
--- @param frame table
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)
	local subject
	if args.page then
		subject = normalisePage(args.page)
		if not subject then
			return ''
		end
	else
		local title = mw.title.getCurrentTitle()
		if title.namespace ~= 0 then
			return ''
		end
		subject = title.text
	end
	local body = p.render(subject)
	if body == '' then
		return ''
	end
	return frame:extensionTag({ name = 'templatestyles', args = { src = STYLES } }) .. body
end

-- Test-only exports. Not part of the public API.
p._internal = { normalisePage = normalisePage }

return p
