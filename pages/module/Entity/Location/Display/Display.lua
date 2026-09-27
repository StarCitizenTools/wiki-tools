require('strict')

--- @module Entity/Location/Display
--- The infobox pieces every Location leaf builds the same way, so a system, a
--- planet and a belt read alike: the starmap sensor meters, the location chain
--- and the anchors it links, the affiliation shown, and the Starmap button and
--- code row.

local meterBar = require('Module:MeterBar')
local locationStarmap = require('Module:Entity/Location/Starmap')
local locationVocabulary = require('Module:Entity/Location/Vocabulary')

local p = {}

--- 0-10 starmap sensor value → display text: one decimal, trailing .0 dropped
--- ("8.13" → "8.1/10", 10 → "10/10"). nil for missing, zero or non-numeric —
--- zero means "no reading" in the starmap data, not an actual rating.
--- @param value any
--- @return string|nil
function p.formatSensor(value)
	local n = tonumber(value)
	if not n or n <= 0 then
		return nil
	end
	local rounded = math.floor(n * 10 + 0.5) / 10
	return tostring(rounded) .. '/10'
end

--- Append a MeterBar sensor row as a full-width block item. Shared so a system
--- and the bodies inside it read their sensor rows the same way.
--- @param items EntityItemData[]
--- @param label string
--- @param value any
function p.appendSensorMeter(items, label, value)
	local text = p.formatSensor(value)
	if not text then
		return
	end
	items[#items + 1] = {
		content = meterBar.render({ label = label, value = tonumber(value), max = 10, text = text }),
		class = 't-infobox-item--block',
	}
end

--- The page an anchor should link, preferring a qualified title only when it
--- is actually there. Both directions occur: a planet can share its name with
--- a disambiguation page while the article sits at "<name> (planet)", as
--- ArcCorp and microTech do, so the bare name is not enough even though it
--- exists; but a binary's component star sits at the bare "Goss A", where the
--- letter already disambiguates and no "(star)" page was ever made.
--- @param name string
--- @param qualifier string
--- @return string
function p.anchorTitle(name, qualifier)
	local qualified = name .. ' (' .. qualifier .. ')'
	local title = mw.title.new(qualified)
	if title and title.exists then
		return qualified
	end
	return name
end

--- What a starmap object orbits, as display name plus link target. A star or
--- black hole takes the '(star)' qualifier, anything else '(planet)'.
--- @param starsystem table|nil
--- @param obj table|nil the object whose parent is wanted
--- @return string|nil name
--- @return string|nil target
function p.celestialParentAnchor(starsystem, obj)
	local parent = locationStarmap.celestialParent(starsystem, obj)
	local name = locationStarmap.celestialName(parent)
	if not name then
		return nil, nil
	end
	if parent.type == 'STAR' or parent.type == 'BLACKHOLE' then
		return name, p.anchorTitle(name, 'star')
	end
	return name, p.anchorTitle(name, 'planet')
end

--- One linked tier of the Location row. The target is linked only when its page
--- exists, so a chain never paints a red link; the display name survives either
--- way. Kept thin and untested offline: the runner's title shim cannot answer
--- `exists`.
--- @param name string|nil
--- @param target string|nil
--- @return string|nil
function p.tier(name, target)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local title = type(target) == 'string' and target ~= '' and mw.title.new(target) or nil
	if title and title.exists then
		return '[[' .. target .. '|' .. name .. ']]'
	end
	return name
end

--- The Location row: `affiliation space › system › parent`. Every leaf that
--- builds one builds the same three tiers, so a belt and a planet in one system
--- read alike; the caller supplies only the parent, which is the one tier each
--- leaf resolves differently.
---
--- The first tier is the SYSTEM's affiliation, never the page's, because it
--- links the systems category and so has to describe the system; a page whose
--- own affiliation differs states it in its own row. The tier shows the COMPACT
--- form ('UEE space', the wording the legacy pages used) while linking the long
--- form, which is what StarSystem files systems under.
--- @param starsystem table|nil
--- @param system string|nil
--- @param parentName string|nil
--- @param parentTarget string|nil
--- @return string|nil
function p.locationChain(starsystem, system, parentName, parentTarget)
	local parts = {}
	local affiliation = locationVocabulary.affiliationEntry(starsystem)
	if affiliation then
		local text = (affiliation.short or affiliation.label) .. ' space'
		parts[#parts + 1] = p.tier(text, ':Category:' .. affiliation.label .. ' systems')
	end
	if system then
		parts[#parts + 1] = p.tier(system .. ' system', system .. ' system')
	end
	parts[#parts + 1] = p.tier(parentName, parentTarget)
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' › ')
end

--- The affiliation to SHOW, as StarSystem shows it: an editor's own markup for
--- free text, the canonical label linked otherwise. A canonical token must NOT
--- render as the editor typed it, or |affiliation=UEE would read a bare 'UEE'
--- next to a sibling page's linked 'United Empire of Earth'.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return string|nil
function p.affiliationDisplay(starsystem, resolved)
	local entry = locationVocabulary.resolveAffiliation(starsystem, resolved)
	if not entry then
		return nil
	end
	return entry.display or ('[[' .. entry.label .. ']]')
end

--- The RSI Starmap footer action button for a starmap code, or no buttons at
--- all when there is no usable code. The Galactapedia mark doubles as the
--- icon (it is technically the Starmap's logo) and the brand class is shared
--- with every other Starmap button on the wiki. One definition for every leaf,
--- so their buttons cannot drift apart.
--- @param code string|nil
--- @return table[]
function p.starmapFooterButtons(code)
	if type(code) ~= 'string' or code == '' then
		return {}
	end
	return {
		{
			label = 'Starmap',
			url = 'https://robertsspaceindustries.com/starmap?location=' .. code,
			icon = 'Sc-icon-galactapedia.svg',
			class = 't-button--branded t-button--starmap',
		},
	}
end

--- The chain-contributed Metadata row for a starmap code: the `?location=` key
--- on the RSI starmap, the same vocabulary the legacy System and Astronomical
--- object templates exposed. Pairs with starmapFooterButtons so a page's button
--- and its printed code always come from the same value.
--- @param code string|nil
--- @return EntityItemData[]
function p.starmapMetadataItems(code)
	if type(code) ~= 'string' or code == '' then
		return {}
	end
	-- One unbreakable token of up to 39 characters
	-- (STANTON.PLANETS.STANTONIHURSTONDYNAMICS), which the row otherwise breaks
	-- mid-segment. <wbr> offers the dots as break points instead and survives
	-- the sanitizer. Parenthesised because gsub also returns a count.
	return { { label = 'Starmap code', content = (code:gsub('%.', '.<wbr>')) } }
end

return p
