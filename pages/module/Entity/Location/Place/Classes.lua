require('strict')

--- @module Entity/Location/Place/Classes
--- The closed class vocabulary of the Place leaf. A class names what a place
--- IS (its function when the name states it, the game's archetype
--- otherwise); where it sits comes from the record, not from here. `zone` is
--- only the default for a page with no record.

local DATA_PAGE = 'Module:Entity/Location/Place/classes.json'

local p = {}

--- The zones a place can occupy. `star` is a place around the star with no
--- body (a gateway), shown on the star's page rather than a planet's.
--- @type table<string, boolean>
p.ZONES = { surface = true, orbit = true, lagrange = true, inside = true, star = true }

--- @type table<string, { name: string, category: string, parent: string, zone: string }>|nil
local index

--- Lower-cased lookup built once per parse. Built with pairs because a
--- mw.loadJsonData table answers neither # nor next().
--- @return table<string, { name: string, category: string, parent: string, zone: string }>
local function build()
	if index then
		return index
	end
	index = {}
	for name, def in pairs(mw.loadJsonData(DATA_PAGE).classes) do
		index[mw.ustring.lower(name)] = {
			name = name,
			category = def.category,
			parent = def.parent,
			zone = def.zone,
		}
	end
	return index
end

--- The class entry for an editor's |classification=, trimmed and matched
--- case-insensitively; nil for anything outside the vocabulary.
--- @param text any
--- @return { name: string, category: string, parent: string, zone: string }|nil
function p.get(text)
	if type(text) ~= 'string' then
		return nil
	end
	local key = mw.ustring.lower(mw.text.trim(text))
	if key == '' then
		return nil
	end
	return build()[key]
end

return p
