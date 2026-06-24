-- tests/manifest.lua
-- Standalone JSON manifest-conformance checks for Module:Entity config files.
-- Run with: lua5.1 tests/manifest.lua (from the repo root), or `mise run test:lua:manifest`.
-- Exit 0 = all pass; exit 1 = failures listed.
-- (The off-wiki ScribuntoUnit suites are run by the mediawiki-scribuntounit
--  library, consumed via mise — see scribuntounit.config.lua + .mise.toml.)

local dkjson = dofile('tests/vendor/dkjson.lua')

local failures = {}
local ok_files = {}

local function fail(file, msg)
	table.insert(failures, file .. ': ' .. msg)
end

local function pass(file)
	table.insert(ok_files, file)
end

--- Read and decode a JSON file, hard-failing on missing/malformed.
--- Returns nil and records a failure instead of erroring, so later
--- checks that depend on the same file can be skipped.
local function readJson(path)
	local f, err = io.open(path, 'r')
	if not f then
		fail(path, 'cannot open file: ' .. tostring(err))
		return nil
	end
	local text = f:read('*a')
	f:close()
	local obj, _, decodeErr = dkjson.decode(text)
	if obj == nil then
		fail(path, 'JSON decode failed: ' .. tostring(decodeErr))
		return nil
	end
	return obj
end

--- Read a plain text file; hard-fail on missing.
local function readFile(path)
	local f, err = io.open(path, 'r')
	if not f then
		fail(path, 'cannot open file: ' .. tostring(err))
		return nil
	end
	local text = f:read('*a')
	f:close()
	return text
end

-- ── Paths ─────────────────────────────────────────────────────────────────────
local BASE = 'pages/module/Entity'

local TYPES_PATH = BASE .. '/Item/types.json'
local CLASSES_PATH = BASE .. '/Item/classifications.json'
local WEAPON_CLASSES_PATH = BASE .. '/Item/WeaponGun/weaponClasses.json'
local ITEM_SITES_PATH = BASE .. '/Item/communitySites.json'
local OFFICIAL_SITES_PATH = BASE .. '/officialSites.json'
local COMM_SITES_PATH = BASE .. '/Commodity/communitySites.json'
local PORTS_CATS_PATH = BASE .. '/Ports/categories.json'
local ITEM_LUA_PATH = BASE .. '/Item/Item.lua'
local VEHICLE_LUA_PATH = BASE .. '/Vehicle/Vehicle.lua'
local VEHICLE_EDITORIAL_PATH = BASE .. '/Vehicle/editorial.json'

-- ── 1. types.json ─────────────────────────────────────────────────────────────
-- Every entry (non-%-prefixed key) has non-empty string name + category; keys unique.
-- (JSON object keys are inherently unique; we verify the value shapes.)
local types = readJson(TYPES_PATH)
if types then
	local typesFailed = false
	for k, v in pairs(types) do
		if type(k) ~= 'string' or k:sub(1, 1) == '%' or k:sub(1, 1) == '_' then
			-- skip meta keys (% or _ prefixed; none expected in types.json, but be safe)
		else
			if type(v) ~= 'table' then
				fail(TYPES_PATH, 'entry ' .. k .. ' is not a table')
				typesFailed = true
			else
				if type(v.name) ~= 'string' or v.name == '' then
					fail(TYPES_PATH, 'entry ' .. k .. ' has missing or empty .name')
					typesFailed = true
				end
				if type(v.category) ~= 'string' or v.category == '' then
					fail(TYPES_PATH, 'entry ' .. k .. ' has missing or empty .category')
					typesFailed = true
				end
			end
		end
	end
	if not typesFailed then
		pass(TYPES_PATH)
	end
end

-- ── 2. classifications.json ───────────────────────────────────────────────────
-- Meta key %description allowed; every non-meta key starts with 'Ship.';
-- no bare 'Ship' key; each entry has non-empty name + category.
local classes = readJson(CLASSES_PATH)
if classes then
	local classesFailed = false

	if classes['Ship'] ~= nil then
		fail(CLASSES_PATH, "has a bare top-level 'Ship' key (intentionally absent — remove it)")
		classesFailed = true
	end

	for k, v in pairs(classes) do
		if type(k) == 'string' and (k:sub(1, 1) == '%' or k:sub(1, 1) == '_') then
			-- allowed meta key (% or _ prefixed), skip
		else
			if type(k) ~= 'string' or k:sub(1, 5) ~= 'Ship.' then
				fail(CLASSES_PATH, 'key ' .. tostring(k) .. " does not start with 'Ship.'")
				classesFailed = true
			else
				if type(v) ~= 'table' then
					fail(CLASSES_PATH, 'entry ' .. k .. ' is not a table')
					classesFailed = true
				else
					if type(v.name) ~= 'string' or v.name == '' then
						fail(CLASSES_PATH, 'entry ' .. k .. ' has missing or empty .name')
						classesFailed = true
					end
					if type(v.category) ~= 'string' or v.category == '' then
						fail(CLASSES_PATH, 'entry ' .. k .. ' has missing or empty .category')
						classesFailed = true
					end
				end
			end
		end
	end
	if not classesFailed then
		pass(CLASSES_PATH)
	end
end

-- ── 3. weaponClasses.json ─────────────────────────────────────────────────────
-- damageTypes: no entry is a leading prefix of another (after lower + space-strip).
local weaponClasses = readJson(WEAPON_CLASSES_PATH)
if weaponClasses then
	local wcFailed = false

	if type(weaponClasses.damageTypes) ~= 'table' then
		fail(WEAPON_CLASSES_PATH, 'missing or non-array .damageTypes')
		wcFailed = true
	else
		-- normalise: lower + remove spaces
		local normalised = {}
		for i, dt in ipairs(weaponClasses.damageTypes) do
			if type(dt) ~= 'string' then
				fail(WEAPON_CLASSES_PATH, 'damageTypes[' .. i .. '] is not a string')
				wcFailed = true
			else
				table.insert(normalised, (dt:lower():gsub('%s+', '')))
			end
		end
		-- check prefix-freedom: no normalised[i] is a strict prefix of normalised[j]
		for i = 1, #normalised do
			for j = 1, #normalised do
				if i ~= j then
					local ni, nj = normalised[i], normalised[j]
					if nj:sub(1, #ni) == ni then
						fail(
							WEAPON_CLASSES_PATH,
							'damageType '
								.. weaponClasses.damageTypes[i]
								.. ' is a leading prefix of '
								.. weaponClasses.damageTypes[j]
								.. ' (after normalisation: '
								.. ni
								.. ' prefixes '
								.. nj
								.. ')'
						)
						wcFailed = true
					end
				end
			end
		end
	end

	-- WeaponGun.lua reads .mechanisms; validate its presence as a consumer-shape
	-- check (same spirit as the site-manifest field checks).
	if type(weaponClasses.mechanisms) ~= 'table' then
		fail(WEAPON_CLASSES_PATH, 'missing or non-array .mechanisms')
		wcFailed = true
	end

	if not wcFailed then
		pass(WEAPON_CLASSES_PATH)
	end
end

-- ── 4. Site manifests ─────────────────────────────────────────────────────────
-- Format.buildSiteLinks reads: def.arg OR (def.format AND def.data); plus def.label.
-- Each entry must have: label (string) AND (arg OR (format AND data)).
local function checkSiteManifest(path)
	local sites = readJson(path)
	if not sites then
		return
	end

	if type(sites) ~= 'table' then
		fail(path, 'expected a JSON array at top level')
		return
	end

	local siteFailed = false
	for i, entry in ipairs(sites) do
		if type(entry) ~= 'table' then
			fail(path, 'entry [' .. i .. '] is not an object')
			siteFailed = true
		else
			-- Must have a non-empty label
			if type(entry.label) ~= 'string' or entry.label == '' then
				fail(path, 'entry [' .. i .. '] has missing or empty .label')
				siteFailed = true
			end
			-- Must have arg OR (format AND data)
			local hasArg = type(entry.arg) == 'string' and entry.arg ~= ''
			local hasFormatData = type(entry.format) == 'string'
				and entry.format ~= ''
				and type(entry.data) == 'string'
				and entry.data ~= ''
			if not hasArg and not hasFormatData then
				fail(
					path,
					'entry [' .. i .. '] (' .. tostring(entry.label) .. '): must have .arg OR both .format and .data'
				)
				siteFailed = true
			end
		end
	end

	if not siteFailed then
		pass(path)
	end
end

checkSiteManifest(ITEM_SITES_PATH)
checkSiteManifest(OFFICIAL_SITES_PATH)
checkSiteManifest(COMM_SITES_PATH)

-- ── 5. Ports/categories.json ──────────────────────────────────────────────────
-- .categories is a table; .typeAliases (if present) is string→string.
-- Meta keys _source and _doc are allowed.
local portsCats = readJson(PORTS_CATS_PATH)
if portsCats then
	local portsFailed = false

	if type(portsCats.categories) ~= 'table' then
		fail(PORTS_CATS_PATH, '.categories is missing or not an object')
		portsFailed = true
	else
		-- Spot-check: every category entry is a table
		for k, v in pairs(portsCats.categories) do
			if type(v) ~= 'table' then
				fail(PORTS_CATS_PATH, '.categories.' .. tostring(k) .. ' is not an object')
				portsFailed = true
			end
		end
	end

	if portsCats.typeAliases ~= nil then
		if type(portsCats.typeAliases) ~= 'table' then
			fail(PORTS_CATS_PATH, '.typeAliases is present but not an object')
			portsFailed = true
		else
			for k, v in pairs(portsCats.typeAliases) do
				if type(k) ~= 'string' or type(v) ~= 'string' then
					fail(
						PORTS_CATS_PATH,
						'.typeAliases entry ' .. tostring(k) .. ' = ' .. tostring(v) .. ' is not string→string'
					)
					portsFailed = true
				end
			end
		end
	end

	if not portsFailed then
		pass(PORTS_CATS_PATH)
	end
end

-- ── 6. itemSubtypeMapping cross-reference ────────────────────────────────────
-- Every key K in Item.lua's itemSubtypeMapping must appear as:
--   types[K]  OR  classes['Ship.'..K]
-- Report orphans (keys that resolve to neither).
local itemLua = readFile(ITEM_LUA_PATH)
if itemLua and types and classes then
	-- Extract the itemSubtypeMapping block and parse keys.
	-- The block is:   local itemSubtypeMapping = { ... }
	-- Keys are identifiers (possibly with underscores) = '...'.
	local mapBlock = itemLua:match('local itemSubtypeMapping%s*=%s*(%b{})')
	if not mapBlock then
		fail(ITEM_LUA_PATH, 'could not locate itemSubtypeMapping table in source')
	else
		local orphans = {}
		-- Match bare identifier keys: Key = '...' or Key = "..."
		-- NOTE: this naive scan also matches "Key =" inside Lua comments within the
		-- table, so do NOT add commented-out "-- Key = ..." placeholders to
		-- itemSubtypeMapping or this cross-check will report a spurious orphan.
		for key in mapBlock:gmatch('([%a_][%a%d_]*)%s*=') do
			-- Skip if types.json has this key directly
			if types[key] == nil then
				-- Check classifications.json for Ship.<key>
				if classes['Ship.' .. key] == nil then
					table.insert(orphans, key)
				end
			end
		end
		if #orphans > 0 then
			for _, k in ipairs(orphans) do
				fail(
					ITEM_LUA_PATH,
					'itemSubtypeMapping key '
						.. k
						.. ' resolves to neither types.json['
						.. k
						.. '] nor classifications.json[Ship.'
						.. k
						.. ']'
				)
			end
		else
			pass(ITEM_LUA_PATH .. ' (itemSubtypeMapping cross-reference)')
		end
	end
end

-- ── 7. properties.json self-check + editorial.json cross-reference ────────────
-- properties.json: every entry has a non-Quantity smw, an allowed unitless
-- bucket, a non-empty modules list, and a desc. Each editorial.json field's smw
-- must resolve to a declared property tagged with the owning module, so an
-- editorial field can never reference an undeclared or mis-tagged SMW property.
local PROPS_PATH = BASE .. '/properties.json'
local ALLOWED_BUCKETS = { PAGE = true, TEXT = true, INTEGER = true, DOUBLE = true, BOOLEAN = true }
local EDITORIAL_MANIFESTS = {
	{ path = BASE .. '/Vehicle/editorial.json', module = 'Vehicle' },
}

local props = readJson(PROPS_PATH)
if props then
	local propsFailed = false
	for name, def in pairs(props) do
		if type(name) == 'string' and name:sub(1, 1) == '%' then
			-- %doc meta, skip
		elseif type(def) ~= 'table' then
			fail(PROPS_PATH, 'entry ' .. tostring(name) .. ' is not an object')
			propsFailed = true
		else
			if type(def.smw) ~= 'string' or def.smw == '' then
				fail(PROPS_PATH, 'entry ' .. name .. ' has missing or empty .smw')
				propsFailed = true
			elseif def.smw == 'Quantity' then
				fail(
					PROPS_PATH,
					'entry ' .. name .. " uses smw 'Quantity' (banned: store unitless, units are a render concern)"
				)
				propsFailed = true
			end
			if type(def.bucket) ~= 'string' or not ALLOWED_BUCKETS[def.bucket] then
				fail(
					PROPS_PATH,
					'entry '
						.. name
						.. ' has invalid .bucket '
						.. tostring(def.bucket)
						.. ' (allowed: PAGE/TEXT/INTEGER/DOUBLE/BOOLEAN)'
				)
				propsFailed = true
			end
			if type(def.modules) ~= 'table' or def.modules[1] == nil then
				fail(PROPS_PATH, 'entry ' .. name .. ' has missing or empty .modules')
				propsFailed = true
			end
			if type(def.desc) ~= 'string' or def.desc == '' then
				fail(PROPS_PATH, 'entry ' .. name .. ' has missing or empty .desc')
				propsFailed = true
			end
		end
	end
	if not propsFailed then
		pass(PROPS_PATH)
	end

	for _, manifest in ipairs(EDITORIAL_MANIFESTS) do
		local ed = readJson(manifest.path)
		if ed then
			local edFailed = false
			for field, def in pairs(ed) do
				if type(field) == 'string' and field:sub(1, 1) == '%' then
					-- %doc meta, skip
				elseif type(def) ~= 'table' then
					fail(manifest.path, 'field ' .. tostring(field) .. ' is not an object')
					edFailed = true
				else
					-- .arg is a non-empty string, or a non-empty list of non-empty
					-- strings (alias args tried in order, e.g. ["series", "model"]).
					local argOk = false
					if type(def.arg) == 'string' then
						argOk = def.arg ~= ''
					elseif type(def.arg) == 'table' and def.arg[1] ~= nil then
						argOk = true
						for _, a in ipairs(def.arg) do
							if type(a) ~= 'string' or a == '' then
								argOk = false
							end
						end
					end
					if not argOk then
						fail(manifest.path, 'field ' .. field .. ' has missing or empty .arg')
						edFailed = true
					end
					local smw = def.smw
					if type(smw) ~= 'string' or smw == '' then
						fail(manifest.path, 'field ' .. field .. ' has missing or empty .smw')
						edFailed = true
					elseif props[smw] == nil then
						fail(
							manifest.path,
							'field ' .. field .. " smw '" .. smw .. "' is not declared in properties.json"
						)
						edFailed = true
					else
						local tagged = false
						for _, m in ipairs(props[smw].modules or {}) do
							if m == manifest.module then
								tagged = true
								break
							end
						end
						if not tagged then
							fail(
								manifest.path,
								'field '
									.. field
									.. " smw '"
									.. smw
									.. "' exists but is not tagged with module '"
									.. manifest.module
									.. "'"
							)
							edFailed = true
						end
					end
				end
			end
			if not edFailed then
				pass(manifest.path)
			end
		end
	end
end

-- ── 8. Vehicle.lua editorial field references ─────────────────────────────────
-- Every key passed to effective(resolved, '<key>') or editorialValue(resolved,
-- '<key>') in Vehicle.lua must be a declared top-level field in editorial.json
-- (excluding the %doc meta key). A typo'd key silently drops an infobox row;
-- this check catches it statically before deployment.
local vehicleLua = readFile(VEHICLE_LUA_PATH)
local vehicleEditorial = readJson(VEHICLE_EDITORIAL_PATH)
if vehicleLua and vehicleEditorial then
	-- Build a set of declared editorial field names (exclude %doc meta key).
	local editorialFields = {}
	for field, _ in pairs(vehicleEditorial) do
		if type(field) == 'string' and field:sub(1, 1) ~= '%' then
			editorialFields[field] = true
		end
	end

	-- Extract every key referenced in any of these shapes:
	--   effective(resolved, 'key', ...)   editorialValue(resolved, 'key')   resolved.key.value
	-- (the third covers direct reads like getHeaderBadge's resolved.production_state.value).
	local missing = {}
	local seen = {}
	local function checkKey(key)
		if not seen[key] then
			seen[key] = true
			if not editorialFields[key] then
				missing[#missing + 1] = key
			end
		end
	end
	for key in vehicleLua:gmatch("effective%(resolved,%s*'([%w_]+)'") do
		checkKey(key)
	end
	for key in vehicleLua:gmatch("editorialValue%(resolved,%s*'([%w_]+)'") do
		checkKey(key)
	end
	for key in vehicleLua:gmatch('resolved%.([%w_]+)%.value') do
		checkKey(key)
	end

	if #missing > 0 then
		for _, k in ipairs(missing) do
			fail(
				VEHICLE_LUA_PATH,
				"editorial field reference '" .. k .. "' is not declared in " .. VEHICLE_EDITORIAL_PATH
			)
		end
	else
		pass(VEHICLE_LUA_PATH .. ' (editorial field cross-reference)')
	end
end

-- ── 9. Consumer require-path contract ────────────────────────────────────────
local CONSUMER_REQUIRES = {
	{
		file = 'pages/module/WearableSet/WearableSet.lua',
		need = { 'Module:Entity/Data', 'Module:Entity/Facet/Environment', 'Module:Entity/Facet/Armor' },
	},
	{ file = 'pages/module/Entity/Orders/Orders.lua', need = { 'Module:Entity/Data', 'Module:Entity/StructuredData' } },
	{
		file = 'pages/module/Entity/Rewards/Rewards.lua',
		need = { 'Module:Entity/Data', 'Module:Entity/StructuredData' },
	},
}
for _, c in ipairs(CONSUMER_REQUIRES) do
	local src = readFile(c.file)
	if src then
		local cFailed = false
		for _, modPath in ipairs(c.need) do
			local pat = 'require%([\'"]' .. modPath:gsub('([%-%.%/])', '%%%1') .. '[\'"]%)'
			if not src:match(pat) then
				fail(c.file, "no longer requires '" .. modPath .. "' (consumer contract broken)")
				cFailed = true
			end
		end
		if not cFailed then
			pass(c.file .. ' (consumer require-path contract)')
		end
	end
end

-- ── Summary ───────────────────────────────────────────────────────────────────
if #failures == 0 then
	for _, f in ipairs(ok_files) do
		print('OK  ' .. f)
	end
	print('\nmanifest: all config files OK')
	os.exit(0)
else
	-- Print passing files first, then failures
	for _, f in ipairs(ok_files) do
		print('OK  ' .. f)
	end
	print('')
	for _, msg in ipairs(failures) do
		print('FAIL  ' .. msg)
	end
	print('\nmanifest: ' .. #failures .. ' failure(s)')
	os.exit(1)
end
