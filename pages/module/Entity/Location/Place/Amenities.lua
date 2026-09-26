require('strict')

--- @module Entity/Location/Place/Amenities
--- A place's amenities, from the API's per-record list of the game's
--- map-legend labels (Maps_Amenities_*). The store keeps the game's names;
--- the infobox groups them and sentence-cases them, dropping the "Buy " the
--- Shops heading already says.

local p = {}

--- Group order, and item order within a group, as { API name, shown label }.
--- "Vehicle Services" is the Cry-Astro maintenance app usable while parked
--- (repair, restock, refuel); the game's own short label is kept.
--- Tiers are medical-bed tiers: a hospital treats up to T1, a clinic up to T2.
--- The API carries no tier.
p.GROUPS = {
	{
		label = 'Vehicles',
		items = {
			{ 'Hangar (XL)', 'Hangar (XL)' },
			{ 'Hangar (L)', 'Hangar (L)' },
			{ 'Hangar (M)', 'Hangar (M)' },
			{ 'Hangar (S)', 'Hangar (S)' },
			{ 'Landing Pad (XL)', 'Landing pad (XL)' },
			{ 'Landing Pad (L)', 'Landing pad (L)' },
			{ 'Landing Pad (M)', 'Landing pad (M)' },
			{ 'Landing Pad (S)', 'Landing pad (S)' },
			{ 'Docking', 'Docking' },
			{ 'Garage', 'Garage' },
			{ 'Vehicle Services', 'Vehicle services' },
		},
	},
	{
		label = 'Trade & industry',
		items = {
			{ 'Commodity Trading', 'Commodity trading' },
			{ 'Refinery', 'Refinery' },
			{ 'Loading Dock', 'Loading dock' },
		},
	},
	{
		label = 'Medical',
		items = {
			{ 'Hospital', 'Hospital (T1)' },
			{ 'Clinic', 'Clinic (T2)' },
		},
	},
	{
		label = 'Shops',
		items = {
			{ 'Buy Armor', 'Armor' },
			{ 'Buy Clothing', 'Clothing' },
			{ 'Buy Ship Items/Weapons', 'Ship items/weapons' },
			{ 'Buy Weapons', 'Weapons' },
			{ 'Buy/Rent Vehicles', 'Buy/rent vehicles' },
			{ 'Buy Vehicles', 'Buy vehicles' },
			{ 'Rent Vehicles', 'Rent vehicles' },
			{ 'Food Court', 'Food court' },
		},
	},
}

--- Every amenity display_name on a record, in API order, deduplicated.
--- @param record table|nil
--- @return string[]
function p.names(record)
	local out, seen = {}, {}
	local list = type(record) == 'table' and record.amenities or nil
	if type(list) ~= 'table' then
		return out
	end
	for _, amenity in ipairs(list) do
		local name = type(amenity) == 'table' and amenity.display_name or nil
		if type(name) == 'string' and name ~= '' and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	return out
end

--- Infobox rows for the groups that have anything, in GROUPS order. A label
--- the table does not know lands in a final "Other" row, so a new game
--- amenity shows up instead of silently dropping.
--- @param names string[]
--- @return { label: string, text: string }[]
function p.group(names)
	local present = {}
	for _, name in ipairs(names) do
		present[name] = true
	end
	local known, rows = {}, {}
	for _, group in ipairs(p.GROUPS) do
		local parts = {}
		for _, item in ipairs(group.items) do
			known[item[1]] = true
			if present[item[1]] then
				parts[#parts + 1] = item[2]
			end
		end
		if parts[1] then
			rows[#rows + 1] = { label = group.label, text = table.concat(parts, ' · ') }
		end
	end
	local other = {}
	for _, name in ipairs(names) do
		if not known[name] then
			other[#other + 1] = name
		end
	end
	if other[1] then
		rows[#rows + 1] = { label = 'Other', text = table.concat(other, ' · ') }
	end
	return rows
end

--- The groups a landing-zone card summarises, in order; each contributes its
--- first facility present (GROUPS lists hangars largest first).
p.SUMMARY_GROUPS = { 'Medical', 'Vehicles', 'Trade & industry' }

--- One short line for a landing-zone card: "Hospital (T1) · Hangar (XL) ·
--- Commodity trading". nil when none of the summarised groups is present.
--- @param names string[]
--- @return string|nil
function p.summary(names)
	local present = {}
	for _, name in ipairs(names or {}) do
		present[name] = true
	end
	local parts = {}
	for _, wanted in ipairs(p.SUMMARY_GROUPS) do
		for _, group in ipairs(p.GROUPS) do
			if group.label == wanted then
				for _, item in ipairs(group.items) do
					if present[item[1]] then
						parts[#parts + 1] = item[2]
						break
					end
				end
			end
		end
	end
	return parts[1] and table.concat(parts, ' · ') or nil
end

return p
