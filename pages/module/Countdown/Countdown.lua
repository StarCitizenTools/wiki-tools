require('strict')

--- @module Countdown
--- A live countdown: the hook a gadget animates, plus a fallback that is true
--- without JavaScript.
---
--- It deliberately does NOT compute the remaining time here. A value worked out
--- at parse time is frozen into the parser cache and can be arbitrarily stale —
--- and a countdown reading "2 days left" for an event that finished last week is
--- worse than no countdown at all. So the dates go out as data attributes, the
--- mainpage gadget does the arithmetic on load, and a reader without JavaScript
--- sees the date range, which stays true forever.
---
--- The module owns the markup and the styling; the gadget owns the numbers. That
--- is the same division Module:Entity's stat line uses, where the server renders
--- a plausible figure and the gadget corrects it — except here the honest
--- fallback is a different fact rather than a stale version of the same one.

local START_ATTR = 'data-gadget-mainpage-countdown-start'
local END_ATTR = 'data-gadget-mainpage-countdown-end'

local p = {}

--- @param iso string
--- @return string|nil formatted, or nil when the date cannot be read
local function formatDate(iso, format)
	if not iso or iso == '' then
		return nil
	end
	local ok, formatted = pcall(function()
		return mw.language.getContentLanguage():formatDate(format, iso)
	end)
	return ok and formatted or nil
end

--- Rejects a date the formatter cannot read. A typo has to be loud: silently
--- rendering nothing is the one outcome nobody notices, and this element's whole
--- job is to be the page's most conspicuous statement about time.
---
--- @param name string parameter name, for the message
--- @param iso string
local function assertReadable(name, iso)
	if not formatDate(iso, 'j F Y') then
		error('Countdown: ' .. name .. ' is not a readable date: ' .. tostring(iso))
	end
end

--- The no-JS reading: a date, or a range when both ends are known. The year is
--- dropped from the opening date when both fall in the same one, so the common
--- case reads "12 – 18 August 2026" rather than repeating itself.
---
--- @param starts string|nil
--- @param ends string
--- @return string
local function fallbackText(starts, ends)
	local endText = formatDate(ends, 'j F Y')
	if not endText then
		return ''
	end
	if not starts or starts == '' then
		return endText
	end

	local sameYear = formatDate(starts, 'Y') == formatDate(ends, 'Y')
	local startText = formatDate(starts, sameYear and 'j F' or 'j F Y')
	if not startText then
		return endText
	end
	return startText .. ' – ' .. endText
end

--- @class CountdownProps
--- @field starts? string  ISO 8601 start. Omit for something already under way;
---        with it the gadget can also render the "starts in" tense.
--- @field ends string     ISO 8601 end. Required.
--- @field label? string   Overrides the gadget's tense-derived label. Rarely
---        wanted — the whole point is that the label follows the dates.
--- @field class? string

--- @param props CountdownProps
--- @return string
function p.render(props)
	if not props.ends or props.ends == '' then
		error('Countdown: ends is required')
	end
	assertReadable('ends', props.ends)
	if props.starts and props.starts ~= '' then
		assertReadable('starts', props.starts)
	end

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Countdown/styles.css' },
	})

	local root = mw.html.create('div'):addClass('t-countdown')
	if props.class and props.class ~= '' then
		root:addClass(props.class)
	end
	root:attr(END_ATTR, props.ends)
	if props.starts and props.starts ~= '' then
		root:attr(START_ATTR, props.starts)
	end
	if props.label and props.label ~= '' then
		root:attr('data-gadget-mainpage-countdown-label', props.label)
	end

	-- The fallback is a real sentence-worth of fact, not an empty shell: if the
	-- gadget never runs, this is what the reader is left with.
	root:tag('div'):addClass('t-countdown__fallback'):wikitext(fallbackText(props.starts, props.ends))

	return styles .. tostring(root)
end

--- Wikitext entry point.
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)
	return p.render({
		starts = args.starts,
		ends = args.ends,
		label = args.label,
		class = args.class,
	})
end

return p
