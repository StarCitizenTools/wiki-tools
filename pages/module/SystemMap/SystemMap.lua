require('strict')

--- @module SystemMap
--- Entry point for {{System map}}. Renders the star -> planet -> moon hierarchy
--- of one star system as a horizontal orbit rail.
---
--- Splits three ways so the logic stays testable: Module:SystemMap/Data builds
--- the model (pure), Module:SystemMap/Renderer builds the markup (pure), and
--- this file supplies everything that needs the parser — the current title,
--- page existence and tracking categories — and hands the rail to
--- Module:CollapsibleCard for the card shell and collapse mechanics.

local Data = require('Module:SystemMap/Data')
local Renderer = require('Module:SystemMap/Renderer')
local CollapsibleCard = require('Module:CollapsibleCard')
local yesno = require('Module:Yesno')

local p = {}

local STYLES = 'Module:SystemMap/styles.css'
local CATEGORY_UNKNOWN_SYSTEM = '[[Category:System map with unknown system]]'
local CATEGORY_BROKEN_LINK = '[[Category:Pages with a broken system map link]]'

--- Walk every body in a model, star first, then planets with their moons.
--- @param model SystemMapModel
--- @param fn fun(body: SystemMapBody)
local function eachBody(model, fn)
	fn(model.star)
	for _, body in ipairs(model.bodies) do
		fn(body)
		for _, moon in ipairs(body.moons) do
			fn(moon)
		end
	end
end

--- Flag bodies whose target page does not exist.
---
--- systems.json is hand-owned, so a page move does not self-heal — this is the
--- tracking category that surfaces the breakage. `exists` is injected so the
--- suite can drive it without a parser; production passes an mw.title probe.
---
--- Cost note: the production probe is an expensive parser function, one call
--- per body plus one for the system article. The limit on this wiki is 100
--- (measured, not the 500 quoted for a stock MediaWiki), and existing usage on
--- the target pages runs 5-14 calls, so the worst case here — Stanton, 18
--- bodies + 1 = 19 — lands around a quarter of the budget. Pyro is 15 and Nyx
--- 7. That is fine for the ~20 system articles this ships on; the deferred
--- rollout to ~1,400 location pages is NOT covered by this arithmetic and needs
--- a different approach (a precomputed existence set, or dropping the probe).
--- Overflow is not graceful — the title library raises a LuaError rather than
--- returning nil — so the caller's probe swallows it (see p.main). If the
--- ceiling ever becomes a real problem, deleting this call is safe: MediaWiki
--- still red-links the target on its own, only the tracking category is lost.
--- @param model SystemMapModel
--- @param exists fun(page: string): boolean
--- @return string category Empty string when nothing is missing
function p.annotateExistence(model, exists)
	local anyMissing = false

	-- The system article itself is linked from the header, so a move of that
	-- page has to trip the category too. There is no body to flag for it.
	if not exists(model.page) then
		anyMissing = true
	end

	eachBody(model, function(body)
		if not exists(body.page) then
			body.missing = true
			anyMissing = true
		end
	end)

	if anyMissing then
		return CATEGORY_BROKEN_LINK
	end
	return ''
end

--- Testable core. Everything parser-dependent arrives as an argument.
--- @param input string|nil        System name as written in the template call
--- @param currentTitle string     Page title being rendered
--- @param exists (fun(page: string): boolean)|nil Existence probe; skipped when nil
--- @param collapsed boolean|nil   Render the box closed
--- @return string
function p.render(input, currentTitle, exists, collapsed)
	local model = Data.buildModel(input, currentTitle)
	if not model then
		return CATEGORY_UNKNOWN_SYSTEM
	end

	local category = ''
	if exists then
		category = p.annotateExistence(model, exists)
	end

	-- The shell — card frame, header row, collapse affordance and chevron — comes
	-- from Module:CollapsibleCard, so the map matches every other card on the
	-- wiki instead of hand-rolling a lookalike. This module only supplies the
	-- title and the rail.
	--
	-- The geometry custom properties do NOT live on this card's root: styles.css
	-- declares them on .t-system-map__scroll, which Module:SystemMap/Renderer
	-- emits itself. See the note on renderRail for why.
	local card = CollapsibleCard.render({
		title = string.format('[[%s|%s]]', model.page, model.page),
		description = Data.summarise(model),
		content = tostring(Renderer.renderRail(model)),
		open = not collapsed,
		class = 't-system-map',
	})

	return card .. category
end

--- Wikitext entry point (backs {{System map}}).
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)

	local styles = frame:extensionTag({ name = 'templatestyles', args = { src = STYLES } })

	-- Exceeding the expensive-parser-function budget raises a LuaError (it is the
	-- `.exists` access that is metered, not mw.title.new, so both sit inside the
	-- pcall). Degrade to "no tracking category" rather than a red script error:
	-- on failure we genuinely do not know whether the page is there, and a false
	-- "missing" flag is worse than a missing category.
	local exists = function(page)
		local ok, result = pcall(function()
			local title = mw.title.new(page)
			return title ~= nil and title.exists
		end)
		if not ok then
			return true
		end
		return result
	end

	local body = p.render(args[1], mw.title.getCurrentTitle().text, exists, yesno(args.collapsed, false))

	return styles .. body
end

return p
