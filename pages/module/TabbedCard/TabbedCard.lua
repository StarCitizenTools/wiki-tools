require('strict')

--- @module TabbedCard
--- A card whose body is a set of tabs: the Module:CardLua shell wrapped around
--- an Extension:TabberNeue tabber, so a group of alternative readings of the
--- same thing sits in one bordered box instead of several stacked ones.
---
--- The card shell supplies the border, surface, radius and corner clipping;
--- this module owns only what changes once a tabber is the card's body — where
--- the tab strip sits against the card edge, and the panel padding.

local card = require('Module:CardLua')

--- Wikitext can only pass a flat arg list, so numbered pairs are the interface:
--- `label1`/`content1`, `label2`/`content2`, … A gap ends the run, so a caller
--- cannot silently lose a tab to a typo in one of the numbers.
local MAX_WIKITEXT_TABS = 20

local p = {}

--- @class TabbedCardTab
--- @field label string   Tab strip text. Required; a tab with no label is dropped.
--- @field content string Panel body, as wikitext or HTML. Required.

--- @class TabbedCardProps
--- @field tabs TabbedCardTab[] Rendered in order; the first is the open tab.
--- @field footer? string       Card footer, below a divider (attribution, source, …).
--- @field flush? boolean       Drop the panel padding, for a body that owns its
---        own edges (a table, an image). Off by default.
--- @field class? string        Extra class(es) appended to the card root.

--- The tabs worth rendering: both a label and content, both non-empty strings.
--- Separate from the render so the arg-shaping is testable without a frame.
---
--- @param tabs TabbedCardTab[]|nil
--- @return TabbedCardTab[]
function p.resolveTabs(tabs)
	local resolved = {}
	for _, tab in ipairs(tabs or {}) do
		local label, content = tab.label, tab.content
		if type(label) == 'string' and label ~= '' and content ~= nil and tostring(content) ~= '' then
			table.insert(resolved, { label = label, content = tostring(content) })
		end
	end
	return resolved
end

--- Lua entry point. Returns '' when no tab survives `resolveTabs`, so a caller
--- can hand over whatever it has without pre-checking and get nothing rather
--- than an empty card.
---
--- @param props TabbedCardProps
--- @return string
function p.render(props)
	local tabs = p.resolveTabs(props.tabs)
	if #tabs == 0 then
		return ''
	end

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:TabbedCard/styles.css' },
	})

	local class = 't-tabbed-card'
	if props.flush == true then
		class = class .. ' t-tabbed-card--flush'
	end
	if props.class and props.class ~= '' then
		class = class .. ' ' .. props.class
	end

	return styles
		.. card.render({
			class = class,
			-- Resolved here rather than captured at module load: the tabber
			-- library is only on the mw global on-wiki, and a load-time capture
			-- would make this module unrequirable off-wiki.
			content = mw.ext.tabber.render(tabs),
			footer = props.footer,
		})
end

--- Wikitext entry point. Reads `label1`/`content1` … `labelN`/`contentN`.
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)
	local yesno = require('Module:Yesno')

	local tabs = {}
	for i = 1, MAX_WIKITEXT_TABS do
		local label, content = args['label' .. i], args['content' .. i]
		if label == nil and content == nil then
			break
		end
		table.insert(tabs, { label = label, content = content })
	end

	return p.render({
		tabs = tabs,
		footer = args.footer,
		flush = yesno(args.flush, false) == true,
		class = args.class,
	})
end

return p
