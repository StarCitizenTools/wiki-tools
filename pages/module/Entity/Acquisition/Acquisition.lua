require('strict')

--- @module Entity/Acquisition
--- Pure helpers shared by the kinds' getAcquisition hooks: acquisition-flag
--- resolution (editor override → derived → Unknown), UEX price-range math, and
--- terminal-card descriptions. The render side (terminal tables, summary grid,
--- footers) lives in Module:Entity/Availability; this module is the logic the
--- kinds use to build their { summary, cards } payload.

local uec = require('Module:UEC')
local yesno = require('Module:Yesno')

local p = {}

--- If arg is true/false, honours the arg (editor override). Otherwise falls back
--- to the derived value (when boolean) or nil (unknown).
--- @param arg string|nil
--- @param derived boolean|nil
--- @return boolean|nil
function p.resolveFlag(arg, derived)
	local override = yesno(arg)
	if override ~= nil then
		return override
	end
	if type(derived) == 'boolean' then
		return derived
	end
	return nil
end

--- Min and max of non-zero numeric entries for `key` (skips UEX zero-sentinels).
--- @param prices table[]
--- @param key string
--- @return number|nil min, number|nil max
function p.priceRange(prices, key)
	local min, max
	for _, entry in ipairs(prices) do
		local v = entry[key]
		if type(v) == 'number' and v > 0 then
			if not min or v < min then
				min = v
			end
			if not max or v > max then
				max = v
			end
		end
	end
	return min, max
end

--- Present non-zero prices for `key` → true; rows exist but all zero → false;
--- array missing/empty → nil (Unknown, so an editor can override).
--- @param prices table[]|nil
--- @param key string
--- @return boolean|nil
function p.inferCanAcquire(prices, key)
	if type(prices) ~= 'table' or #prices == 0 then
		return nil
	end
	local min = p.priceRange(prices, key)
	return min ~= nil
end

--- Scans apiData.entity_tag_map for a tag by name: present → true; map without
--- the tag → false; map missing → nil.
--- @param apiData table
--- @param tagName string
--- @return boolean|nil
function p.hasEntityTag(apiData, tagName)
	local tags = apiData.entity_tag_map
	if type(tags) ~= 'table' then
		return nil
	end
	for _, tag in ipairs(tags) do
		if tag.name == tagName then
			return true
		end
	end
	return false
end

--- The UEC component for the price span (glyph + "7" or "7–12"); nil when no
--- non-zero prices.
--- @param min number|nil
--- @param max number|nil
--- @return string|nil
function p.formatPriceRange(min, max)
	if not min then
		return nil
	end
	return uec._range(min, max)
end

--- "N locations" or "1 location".
--- @param prices table[]
--- @return string
function p.locationCountLabel(prices)
	local n = #prices
	return n == 1 and '1 location' or (n .. ' locations')
end

--- Two-sided market description: "N locations · Buy X · Sell Y".
--- @param prices table[]
--- @return string
function p.buildShopTerminalsDescription(prices)
	local buyText = p.formatPriceRange(p.priceRange(prices, 'price_buy'))
	local sellText = p.formatPriceRange(p.priceRange(prices, 'price_sell'))
	local parts = { p.locationCountLabel(prices) }
	if buyText then
		table.insert(parts, 'Buy ' .. buyText)
	end
	table.insert(parts, 'Sell ' .. sellText)
	return table.concat(parts, ' · ')
end

--- Single-axis market description: "N locations · <range>".
--- @param prices table[]
--- @param key string
--- @return string
function p.buildSinglePriceDescription(prices, key)
	local rangeText = p.formatPriceRange(p.priceRange(prices, key))
	local parts = { p.locationCountLabel(prices) }
	if rangeText then
		table.insert(parts, rangeText)
	end
	return table.concat(parts, ' · ')
end

return p
