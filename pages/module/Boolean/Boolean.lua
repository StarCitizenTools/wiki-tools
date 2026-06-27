require('strict')

--- @module Boolean
--- Renders a tri-state boolean (true / false / nil) as a machine-readable icon:
--- a green check, a grey cross, or an amber help glyph. The single source of
--- truth for the yes / no / unknown icon + colour + label, shared by the
--- {{Boolean}} wikitext template, the Entity infobox facets, and the AG Grid
--- `boolean` column kind. Modeled on Module:DietaryEffect.

local yesno = require('Module:Yesno')
local Icon = require('Module:Icon')

local p = {}

local ICON_SIZE = '16px'

--- @class BooleanState
--- @field state string  'yes' | 'no' | 'unknown'
--- @field icon string   Codex SVG file name (without the File: prefix)
--- @field label string  Display word

--- @type table<string, BooleanState>
local STATES = {
	yes = { state = 'yes', icon = 'CdxIconSuccess.svg', label = 'Yes' },
	no = { state = 'no', icon = 'CdxIconClear.svg', label = 'No' },
	unknown = { state = 'unknown', icon = 'CdxIconHelpNotice.svg', label = 'Unknown' },
}

--- Classify a value into its state entry. Input runs through Module:Yesno, so
--- `yes`/`1`/`true` -> yes, `no`/`0`/`false` -> no; nil / unrecognised -> unknown.
--- @param value any
--- @return BooleanState
function p.classify(value)
	local b = yesno(value)
	if b == true then
		return STATES.yes
	end
	if b == false then
		return STATES.no
	end
	return STATES.unknown
end

--- Render an icon-only inline representation. The returned markup includes its
--- own and Module:Icon's <templatestyles> (MediaWiki dedupes repeated tags), so
--- a facet can drop the string straight into a row's `content`.
---
--- Machine-readable three ways: `title` (hover tooltip), `data-state` (scrapers /
--- AI agents query [data-state]), and a visually-hidden text span (screen
--- readers, translation tools, reader modes -- which ignore aria-label).
--- @param value any
--- @return string
function p.render(value)
	local s = p.classify(value)
	local glyph = Icon.render({ icon = s.icon, mask = true, size = ICON_SIZE })

	local span = mw.html
		.create('span')
		:addClass('t-boolean')
		:addClass('t-boolean--' .. s.state)
		:attr('data-state', s.state)
		:attr('title', s.label)
		:wikitext(glyph)
	span:tag('span'):addClass('t-boolean__sr'):wikitext(s.label)

	local frame = mw.getCurrentFrame()
	local styles = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Boolean/styles.css' } })
	local iconStyles = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })
	return styles .. iconStyles .. tostring(span)
end

--- Classify a value for an AG Grid boolean cell (Module:AGGridColumns/Kind/Boolean).
--- Pure: `text` is the sort / set-filter key, `icon` a file name resolved
--- downstream. Mirrors DietaryEffect.gridClassify.
--- @param value any
--- @return { text: string, state: string, icon: string }
function p.gridClassify(value)
	local s = p.classify(value)
	return { text = s.label, state = s.state, icon = s.icon }
end

--- Wikitext entry point (backs {{Boolean}}). First positional arg is the value.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)
	return p.render(args[1])
end

return p
