require('strict')

--- @module DietaryEffect
--- Classifies the dietary effects carried by food, drink, and edible commodities
--- and renders them as coloured Module:BadgeLua badges: green (with an up arrow)
--- for beneficial effects, red (down arrow) for detrimental ones, neutral grey
--- for `None` and anything unrecognised. The single source of truth for effect
--- polarity and the correct effect page, shared by the consumable infobox facet
--- and the dietary-effect data tables.
---
--- The API sends effect values whose spelling and casing do not always match
--- their wiki page (e.g. `Cognitive Boosting` -> [[Cognitive boosting]],
--- `Hyper-Metabolic` / `Hypermetabolic` -> [[Hyper-metabolic]]), and two stray
--- redirects point at the wrong page (`Healing` -> [[Medical]] rather than the
--- dietary effect; `Hypometabolic` -> [[Hyper-metabolic]]). Lookups are therefore
--- normalised (lower-cased, spaces and hyphens stripped) so every spelling
--- resolves to one entry that carries the canonical page and a canonical display
--- label.

local BadgeLua = require('Module:BadgeLua')

local p = {}

local POSITIVE = 'positive'
local NEGATIVE = 'negative'
local NEUTRAL = 'neutral'

--- Polarity + presentation per polarity. Positive / negative map onto BadgeLua's
--- semantic variants (theme-aware Citizen --color-success / --color-destructive
--- tokens) plus a Codex direction arrow rendered as a currentColor mask (so the
--- arrow tints to the badge colour); neutral is the default grey badge, no arrow.
local PRESENTATION = {
	[POSITIVE] = { variant = 'success', icon = 'CdxIconArrowUp.svg', mask = true },
	[NEGATIVE] = { variant = 'error', icon = 'CdxIconArrowDown.svg', mask = true },
	[NEUTRAL] = {},
}

--- Effect classification, keyed by normalised effect value. `page` is the wiki
--- page the badge links to (nil = render the label as plain text); `label` is the
--- canonical display spelling.
--- @type table<string, { polarity: string, page: string|nil, label: string }>
local EFFECTS = {
	cognitiveboosting = { polarity = POSITIVE, page = 'Cognitive boosting', label = 'Cognitive Boosting' },
	energizing = { polarity = POSITIVE, page = 'Energizing', label = 'Energizing' },
	hydrating = { polarity = POSITIVE, page = 'Hydrating', label = 'Hydrating' },
	hypertrophic = { polarity = POSITIVE, page = 'Hypertrophic', label = 'Hypertrophic' },
	immuneboosting = { polarity = POSITIVE, page = 'Immune boosting', label = 'Immune Boosting' },
	healing = { polarity = POSITIVE, page = 'Healing (dietary effect)', label = 'Healing' },
	hypometabolic = { polarity = POSITIVE, page = 'Hypo-metabolic', label = 'Hypo-Metabolic' },

	atrophic = { polarity = NEGATIVE, page = 'Atrophic', label = 'Atrophic' },
	cognitiveimpairment = { polarity = NEGATIVE, page = 'Cognitive impairing', label = 'Cognitive Impairment' },
	dehydrating = { polarity = NEGATIVE, page = 'Dehydrating', label = 'Dehydrating' },
	fatiguing = { polarity = NEGATIVE, page = 'Fatiguing', label = 'Fatiguing' },
	immunesuppressing = { polarity = NEGATIVE, page = 'Immune suppressing', label = 'Immune Suppressing' },
	toxic = { polarity = NEGATIVE, page = 'Toxic', label = 'Toxic' },
	hypermetabolic = { polarity = NEGATIVE, page = 'Hyper-metabolic', label = 'Hyper-Metabolic' },

	none = { polarity = NEUTRAL, page = nil, label = 'None' },
}

--- Normalise an effect value for lookup: trim, lower-case, strip spaces and
--- hyphens so spelling variants (`Hyper-Metabolic` / `Hypermetabolic`) collapse.
--- @param name string
--- @return string
local function normalize(name)
	return (mw.ustring.lower(mw.text.trim(name)):gsub('[%s%-]', ''))
end

--- Classify an effect value.
--- @param name string
--- @return { polarity: string, page: string|nil, label: string }|nil  nil when unrecognised
function p.classify(name)
	if type(name) ~= 'string' then
		return nil
	end
	return EFFECTS[normalize(name)]
end

--- Render a single effect as a badge. The whole badge links to the effect's
--- canonical page (except neutral `None`, which is unlinked); an unrecognised
--- effect links to its own name (a redlink is the normal signal to create the
--- page). Positive/negative arrows are currentColor masks, so they tint to the
--- badge colour.
--- @param name string
--- @return string
function p.renderBadge(name)
	local entry = p.classify(name)
	local polarity, page, label
	if entry then
		polarity, page, label = entry.polarity, entry.page, entry.label
	else
		polarity, page, label = NEUTRAL, name, name
	end

	local presentation = PRESENTATION[polarity] or {}
	return BadgeLua.render({
		text = label,
		link = page,
		variant = presentation.variant,
		icon = presentation.icon,
		mask = presentation.mask,
	})
end

--- Classify an effect for an AG Grid badge cell (the data table's `kind=effect`
--- column). Pure: returns the per-effect fields a badge needs; `icon` is a file
--- name and `href` a page title, both resolved downstream (the kind resolves the
--- file URL and the link). Mirrors renderBadge's polarity/page/label choices.
--- @param name string
--- @return { text: string, variant: string|nil, icon: string|nil, href: string|nil }
function p.gridClassify(name)
	local entry = p.classify(name)
	local polarity, page, label
	if entry then
		polarity, page, label = entry.polarity, entry.page, entry.label
	else
		polarity, page, label = NEUTRAL, name, name
	end

	local presentation = PRESENTATION[polarity] or {}
	return {
		text = label,
		variant = presentation.variant,
		icon = presentation.icon,
		href = page,
	}
end

--- Render a list of effects as a wrapping row of badges, or nil when empty.
--- @param effects string[]|nil
--- @return string|nil
function p.renderBadges(effects)
	-- effects[1] (not #) sidesteps the frozen-table length quirk on JSON arrays.
	if type(effects) ~= 'table' or effects[1] == nil then
		return nil
	end

	local container = mw.html.create('div'):addClass('t-dietary-effects')
	for _, name in ipairs(effects) do
		container:wikitext(p.renderBadge(name))
	end

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:DietaryEffect/styles.css' },
	})
	return styles .. tostring(container)
end

return p
