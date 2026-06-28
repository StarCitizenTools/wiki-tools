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

--- All maximal digit runs in a version string as a numeric vector, so versions
--- compare component-wise (4.10 > 4.8) rather than lexicographically (where the
--- string "4.8" sorts after "4.10"). The trailing build number becomes the last,
--- tie-breaking component. e.g. "4.10.0-LIVE.100" → { 4, 10, 0, 100 }.
--- @param version string
--- @return number[]
local function versionVector(version)
	local v = {}
	for digits in version:gmatch('%d+') do
		v[#v + 1] = tonumber(digits)
	end
	return v
end

--- True when version vector `a` is strictly newer than `b`, compared
--- component-wise (missing components count as 0).
--- @param a number[]
--- @param b number[]
--- @return boolean
local function versionNewer(a, b)
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then
			return x > y
		end
	end
	return false
end

--- The newest `game_version` present across price rows, or nil when none carry
--- one (older UEX records that predate version stamping).
--- @param rows table[]
--- @return string|nil
local function latestVersion(rows)
	local best, bestVec
	for _, row in ipairs(rows) do
		local gv = row.game_version
		if type(gv) == 'string' and gv ~= '' then
			local vec = versionVector(gv)
			if not best or versionNewer(vec, bestVec) then
				best, bestVec = gv, vec
			end
		end
	end
	return best
end

--- Non-zero numeric prices at `key`, restricted to rows matching `version` when
--- given (nil → every row). Skips UEX zero-sentinels.
--- @param rows table[]
--- @param key string
--- @param version string|nil
--- @return number[]
local function collectPrices(rows, key, version)
	local out = {}
	for _, row in ipairs(rows) do
		if version == nil or row.game_version == version then
			local v = tonumber(row[key])
			if v and v > 0 then
				out[#out + 1] = v
			end
		end
	end
	return out
end

--- Median of a numeric list, rounded to the nearest integer (prices are whole
--- aUEC); even counts average the middle pair. nil for an empty list.
--- @param values number[]
--- @return number|nil
local function median(values)
	local n = #values
	if n == 0 then
		return nil
	end
	table.sort(values)
	local m
	if n % 2 == 1 then
		m = values[(n + 1) / 2]
	else
		m = (values[n / 2] + values[n / 2 + 1]) / 2
	end
	return math.floor(m + 0.5)
end

--- Estimated in-game price at `key` (price_buy / price_rent): the median across
--- the newest patch's terminals, falling back to all patches when the newest
--- carries no usable price for this side. Median over mean resists a single
--- mispriced terminal (they coincide for the common 1–2 terminal case). nil when
--- there is no non-zero price at all.
--- @param rows table[]|nil
--- @param key string
--- @return number|nil
function p.estimatePrice(rows, key)
	if type(rows) ~= 'table' or rows[1] == nil then
		return nil
	end
	local version = latestVersion(rows)
	local values = collectPrices(rows, key, version)
	if #values == 0 and version ~= nil then
		values = collectPrices(rows, key, nil) -- newest patch lacks this side → any patch
	end
	return median(values)
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
