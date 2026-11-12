require('strict')

local collapsibleCard = require('Module:CollapsibleCard')
local yesno = require('Module:Yesno')
local tableLua = require('Module:TableLua')

local PLACEHOLDER = 'Placeholderv2a.png'

local function sentenceCase(str)
	return (str:gsub('^%l', string.upper))
end

local function linked(str)
	if type(str) == 'string' then
		return '[[' .. str .. ']]'
	end
	return str
end

--- Maps the flag value to a state slug used as the BEM modifier
--- suffix on the summary item (`…-item--yes` etc.) and as the
--- canonical `data-state` attribute. CSS uses a descendant selector
--- to set the value icon and color from the item's state, so any
--- future card-level treatment (background tint, etc.) can target the
--- item directly without reaching in.
---
--- @param value boolean|nil
--- @return string
local function flagState(value)
	if value == true then
		return 'yes'
	end
	if value == false then
		return 'no'
	end
	return 'unknown'
end

--- true → "Yes", false → "No", nil → "Unknown". Module:Yesno already
--- collapses input variations to this three-state logic. Rendered as
--- visually-hidden text inside the summary value cell — sighted
--- readers see the icon, assistive tech / reader modes / translators
--- read this text.
---
--- @param value boolean|nil
--- @return string
local function formatFlag(value)
	if value == true then
		return 'Yes'
	end
	if value == false then
		return 'No'
	end
	return 'Unknown'
end

--- If arg is true/false, honours the arg (editor override). Otherwise
--- falls back to the derived value (when it's a boolean) or nil.
---
--- @param arg string|nil
--- @param derived boolean|nil
--- @return boolean|nil
local function resolveFlag(arg, derived)
	local override = yesno(arg)
	if override ~= nil then
		return override
	end
	if type(derived) == 'boolean' then
		return derived
	end
	return nil
end

--- Renders the summary rows as a grid of label/value items. Each item
--- has a category icon + label on the left and a value `<dd>` on the
--- right styled as a 16×16 mask-image icon. The state ("yes" / "no" /
--- "unknown") lives on the item element (the dt/dd pair's wrapper)
--- rather than the value cell, so card-level treatment (background
--- tint, border accent, etc.) can target the item directly:
---  * `data-state` on the item `<div>` is the canonical
---    machine-readable target — scrapers and AI agents query
---    `[data-state]` rather than parsing class modifiers.
---  * A visually-hidden `<span>` inside the `<dd>` carries the
---    human-readable text ("Yes" / "No" / "Unknown"). Screen readers
---    announce it as the `<dd>`'s content; translation tools and reader
---    modes pick it up too (both of which can ignore `aria-label`).
--- The category icon span carries `aria-hidden="true"` so screen
--- readers don't double-announce it on top of the visible label text.
--- Always shows every row so the layout stays stable across pages.
---
--- @param rows { label: string, icon: string|nil, value: boolean|nil }[]
--- @return string
local function renderSummary(rows)
	local root = mw.html.create('dl'):addClass('t-wearable_set-variants-summary')
	for _, row in ipairs(rows) do
		local state = flagState(row.value)
		local itemHtml = root:tag('div')
			:addClass('t-wearable_set-variants-summary-item')
			:addClass('t-wearable_set-variants-summary-item--' .. state)
			:attr('data-state', state)
		local labelHtml = itemHtml:tag('dt'):addClass('t-wearable_set-variants-summary-label')
		if row.icon and row.icon ~= '' then
			labelHtml
				:tag('span')
				:addClass('t-wearable_set-variants-summary-icon')
				:attr('aria-hidden', 'true')
				:wikitext(row.icon)
		end
		labelHtml:wikitext(row.label)
		itemHtml
			:tag('dd')
			:addClass('t-wearable_set-variants-summary-value')
			:tag('span')
			:addClass('t-wearable_set-variants-summary-value-text')
			:wikitext(formatFlag(row.value))
	end
	return tostring(root)
end

--- Builds the ordered list of summary rows for an item entity:
--- Buy, Loot, Craft, Pledge (Rent only when the editor explicitly
--- sets canRent — items aren't structurally rentable). All derived
--- values can be overridden via the matching `canX` arg.
---
--- @param args table
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildItemSummaryRows(args)
	local rows = {}

	if resolveFlag(args.canBuy) then
		table.insert(rows, {
			label = 'Buy',
			icon = '🛒',
			value = resolveFlag(args.canBuy),
		})
	end

	if resolveFlag(args.canWikelo) then
		table.insert(rows, {
			label = 'Wikelo',
			icon = '👽',
			value = resolveFlag(args.canWikelo),
		})
	end

	if resolveFlag(args.canLoot) then
		table.insert(rows, {
			label = 'Loot',
			icon = '📦',
			value = resolveFlag(args.canLoot),
		})
	end

	if resolveFlag(args.canCraft) then
		table.insert(rows, {
			label = 'Craft',
			icon = '🔨',
			value = resolveFlag(args.canCraft),
		})
	end

	if resolveFlag(args.canPledge) then
		table.insert(rows, {
			label = 'Pledge',
			icon = '💵',
			value = resolveFlag(args.canPledge),
		})
	end

	return rows
end

local function buildCard(data, variant, isBase)
	if not variant and not isBase then
		return nil
	end

	local formatted = { variant = '' }
	if isBase then
		variant = data.name
	else
		formatted.variant = ' ' .. variant
	end

	local function component(type)
		if data.overrides[type] then
			return data.overrides[type]
		elseif data.override then
			local str, n = data.override:gsub('#variant', formatted.variant)

			if n > 0 then
				str = str:gsub('#type', sentenceCase(type))
				return str
			else
				return string.format('%s %s%s', data.override, sentenceCase(type), formatted.variant)
			end
		elseif data.global.overrides[type] then
			local str, n = data.global.overrides[type]:gsub('#variant', formatted.variant)

			if n > 0 then
				str = str:gsub('#type', sentenceCase(type))
				return str
			else
				return string.format('%s %s%s', data.global.overrides[type], sentenceCase(type), formatted.variant)
			end
		elseif data.global.override then
			local str, n = data.global.override:gsub('#variant', formatted.variant)

			if n > 0 then
				str = str:gsub('#type', sentenceCase(type))
				return str
			else
				return string.format('%s %s%s', data.global.override, sentenceCase(type), formatted.variant)
			end
		else
			return string.format('%s %s%s', data.name, sentenceCase(type), formatted.variant)
		end
	end

	return {
		title = variant,
		open = isBase or false,
		image = data.image or PLACEHOLDER,
		note = data.note,
		description = data.description or '-',
		summary = buildItemSummaryRows(data.availability),
		undersuit = yesno(data.components.hasUndersuit) and component('undersuit') or nil,
		helmet = yesno(data.components.hasHelmet) and component('helmet') or nil,
		core = yesno(data.components.hasCore) and component('core') or nil,
		backpack = yesno(data.components.hasBackpack) and component('backpack') or nil,
		arms = yesno(data.components.hasArms) and component('arms') or nil,
		legs = yesno(data.components.hasLegs) and component('legs') or nil,
	}
end

local function renderCard(data)
	local titleSection = mw.html.create('div'):addClass('t-wearable_set-variants-title_section')
	local contentSection = mw.html.create('div'):addClass('t-wearable_set-variants-content_section')

	if data.image == PLACEHOLDER then
		titleSection
			:tag('div')
			:addClass('t-wearable_set-variants-title_section__image')
			:wikitext(string.format('[[File:%s|center|frameless|62px|link=|class=noviewer]]', data.image))
			:done()
	else
		titleSection
			:tag('div')
			:addClass('t-wearable_set-variants-title_section__image')
			:wikitext(string.format('[[File:%s|center|frameless|62px]]', data.image))
			:done()
	end
	titleSection
		:tag('div')
		:addClass('t-wearable_set-variants-title_section__container')
		:tag('div')
		:addClass('t-wearable_set-variants-title_section__title')
		:attr('id', data.title)
		:wikitext(data.title)
		:done()
		:tag('div')
		:addClass('t-wearable_set-variants-title_section__description')
		:wikitext(data.description)
		:done()
		:tag('div')
		:addClass('t-wearable_set-variants-title_section__summary')
		:wikitext(renderSummary(data.summary))
		:done()
		:done()
		:done()

	local componentTable = tableLua.render({
		caption = 'Variant armor parts',
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = {
			{ id = 'c1', textAlign = 'center', allowSort = false },
			{ id = 'c2', textAlign = 'center', allowSort = false },
			{ id = 'c3', textAlign = 'center', allowSort = false },
		},
		data = {
			{
				data.undersuit and linked(data.undersuit) or "''no undersuit in set''",
				data.helmet and linked(data.helmet) or "''no helmet in set''",
				data.core and linked(data.core) or "''no core in set''",
			},
			{
				data.backpack and linked(data.backpack) or "''no backpack in set''",
				data.arms and linked(data.arms) or "''no arms in set''",
				data.legs and linked(data.legs) or "''no legs in set''",
			},
		},
	})

	contentSection
		:tag('div')
		:addClass('t-wearable_set-variants-content_section__note')
		:wikitext(data.note)
		:done()
		:tag('div')
		:addClass('t-wearable_set-variants-content_section__components')
		:wikitext(componentTable)
		:done()
		:done()

	return collapsibleCard.render({
		class = 't-wearable_set-variants-card',
		open = data.open,
		title = tostring(titleSection),
		content = tostring(contentSection),
	})
end

local Variants = {}

--- @param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function Variants.main(frame)
	local args = require('Module:Arguments').getArgs(frame)

	local data = {
		name = args.name or mw.title.getCurrentTitle().subpageText,
		description = args.description or nil,
		override = args.override or nil,
		overrides = {
			undersuit = args.undersuit or nil,
			helmet = args.helmet or nil,
			core = args.core or nil,
			backpack = args.backpack or nil,
			arms = args.arms or nil,
			legs = args.legs or nil,
		},
		availability = {
			canBuy = args.canBuy or false,
			canWikelo = args.canWikelo or false,
			canLoot = args.canLoot or false,
			canCraft = args.canCraft or false,
			canPledge = args.canPledge or false,
		},
		components = {
			hasUndersuit = args.hasUndersuit or false,
			hasHelmet = args.hasHelmet or false,
			hasCore = args.hasCore or false,
			hasBackpack = args.hasBackpack or false,
			hasArms = args.hasArms or false,
			hasLegs = args.hasLegs or false,
		},
		hasBase = yesno(args.hasBase),
		note = args.note or nil,
	}

	local output = ''

	if data.hasBase then
		local baseData = {
			name = data.name,
			image = args['image-(base)'] or PLACEHOLDER,
			description = args['description-(base)'] or nil,
			override = args['override-(base)'] or nil,
			global = {
				override = data.override,
				overrides = data.overrides,
			},
			overrides = {
				undersuit = args['undersuit-(base)'] or nil,
				helmet = args['helmet-(base)'] or nil,
				core = args['core-(base)'] or nil,
				backpack = args['backpack-(base)'] or nil,
				arms = args['arms-(base)'] or nil,
				legs = args['legs-(base)'] or nil,
			},
			availability = {
				canBuy = args['canBuy-(base)'] or data.availability.canBuy,
				canWikelo = args['canWikelo-(base)'] or data.availability.canWikelo,
				canLoot = args['canLoot-(base)'] or data.availability.canLoot,
				canCraft = args['canCraft-(base)'] or data.availability.canCraft,
				canPledge = args['canPledge-(base)'] or data.availability.canPledge,
			},
			components = {
				hasUndersuit = args['hasUndersuit-(base)'] or data.components.hasUndersuit,
				hasHelmet = args['hasHelmet-(base)'] or data.components.hasHelmet,
				hasCore = args['hasCore-(base)'] or data.components.hasCore,
				hasBackpack = args['hasBackpack-(base)'] or data.components.hasBackpack,
				hasArms = args['hasArms-(base)'] or data.components.hasArms,
				hasLegs = args['hasLegs-(base)'] or data.components.hasLegs,
			},
			note = args['note-(base)'] or data.note or nil,
		}

		output = output .. renderCard(buildCard(baseData, '', true))
	end

	if args.variants then
		for variant in string.gmatch(args.variants, '([^,]+)') do
			variant = string.gsub(variant, '^%s*(.-)%s*$', '%1')
			local variantData = {
				name = data.name,
				image = args['image-' .. variant] or PLACEHOLDER,
				description = args['description-' .. variant] or nil,
				override = args['override-' .. variant] or nil,
				global = {
					override = data.override,
					overrides = data.overrides,
				},
				overrides = {
					undersuit = args['undersuit-' .. variant] or nil,
					helmet = args['helmet-' .. variant] or nil,
					core = args['core-' .. variant] or nil,
					backpack = args['backpack-' .. variant] or nil,
					arms = args['arms-' .. variant] or nil,
					legs = args['legs-' .. variant] or nil,
				},
				availability = {
					canBuy = args['canBuy-' .. variant] or data.availability.canBuy,
					canWikelo = args['canWikelo-' .. variant] or data.availability.canWikelo,
					canLoot = args['canLoot-' .. variant] or data.availability.canLoot,
					canCraft = args['canCraft-' .. variant] or data.availability.canCraft,
					canPledge = args['canPledge-' .. variant] or data.availability.canPledge,
				},
				components = {
					hasUndersuit = args['hasUndersuit-' .. variant] or data.components.hasUndersuit,
					hasHelmet = args['hasHelmet-' .. variant] or data.components.hasHelmet,
					hasCore = args['hasCore-' .. variant] or data.components.hasCore,
					hasBackpack = args['hasBackpack-' .. variant] or data.components.hasBackpack,
					hasArms = args['hasArms-' .. variant] or data.components.hasArms,
					hasLegs = args['hasLegs-' .. variant] or data.components.hasLegs,
				},
				note = args['note-' .. variant] or data.note or nil,
			}

			output = output .. renderCard(buildCard(variantData, variant, false))
		end
	end

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:WearableSet/Variants/styles.css' },
	})

	return styles .. output
end

return Variants
