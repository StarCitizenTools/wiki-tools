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
	-- Keys are identifiers (possibly with underscores) whose value is a loader:
	--   Key = function() return require('Module:Entity/Item/X') end.
	local mapBlock = itemLua:match('local itemSubtypeMapping%s*=%s*(%b{})')
	if not mapBlock then
		fail(ITEM_LUA_PATH, 'could not locate itemSubtypeMapping table in source')
	else
		local orphans = {}
		-- Match identifier keys whose value starts `function`, so a `key =`
		-- inside a loader body is not mistaken for another entry.
		for key in mapBlock:gmatch('([%a_][%w_]*)%s*=%s*function') do
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
-- properties.json: every entry has an allowed type, an allowed bucket, a
-- non-empty modules list, and a desc. Each editorial.json field's property must
-- resolve to a declared property tagged with the owning module, so an
-- editorial field can never reference an undeclared or mis-tagged property.
local PROPS_PATH = BASE .. '/properties.json'
local ALLOWED_TYPES = { PAGE = true, TEXT = true, INTEGER = true, DOUBLE = true, BOOLEAN = true }
local ALLOWED_BUCKET_NAMES = {
	entity = true,
	vehicle = true,
	vehicle_stats = true,
	item_weapon = true,
	item_component = true,
	item_tool = true,
	commodity = true,
	location = true,
	mission = true,
	company = true,
	wearable_set = true,
}
local EDITORIAL_MANIFESTS = {
	{ path = BASE .. '/Vehicle/editorial.json', module = 'Vehicle' },
}

local props = readJson(PROPS_PATH)
if props then
	local propsFailed = false
	for name, def in pairs(props) do
		if type(name) == 'string' and name:sub(1, 1) == '%' then
			-- meta key (%doc, %kinds), checked separately
		elseif type(def) ~= 'table' then
			fail(PROPS_PATH, 'entry ' .. tostring(name) .. ' is not an object')
			propsFailed = true
		else
			if type(def.type) ~= 'string' or not ALLOWED_TYPES[def.type] then
				fail(
					PROPS_PATH,
					'entry '
						.. name
						.. ' has invalid .type '
						.. tostring(def.type)
						.. ' (allowed: PAGE/TEXT/INTEGER/DOUBLE/BOOLEAN)'
				)
				propsFailed = true
			end
			if def.multi ~= nil then
				fail(PROPS_PATH, 'entry ' .. name .. ' still uses .multi (rename to .repeated)')
				propsFailed = true
			end
			if type(def.field) ~= 'string' or not def.field:match('^[a-z][a-z0-9_]*$') then
				fail(PROPS_PATH, 'entry ' .. name .. ' has missing or non-snake_case .field ' .. tostring(def.field))
				propsFailed = true
			end
			if type(def.bucket) ~= 'string' and type(def.bucket) ~= 'table' then
				fail(PROPS_PATH, 'entry ' .. name .. ' has missing .bucket (string, or object keyed by kind)')
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
					-- .property is optional: absence means display-only (not stored).
					-- If present it names a properties.json key, which must be
					-- declared there.
					local property = def.property
					if property ~= nil then
						if type(property) ~= 'string' or property == '' then
							fail(manifest.path, 'field ' .. field .. ' has non-string or empty .property')
							edFailed = true
						elseif props[property] == nil then
							fail(
								manifest.path,
								'field ' .. field .. " property '" .. property .. "' is not declared in properties.json"
							)
							edFailed = true
						else
							local tagged = false
							for _, m in ipairs(props[property].modules or {}) do
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
										.. " property '"
										.. property
										.. "' exists but is not tagged with module '"
										.. manifest.module
										.. "'"
								)
								edFailed = true
							end
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

-- ── 8. Vehicle editorial field references ────────────────────────────────────
-- Every key passed to an Editorial view's :value('<key>') anywhere under
-- Vehicle/ must be a declared top-level field in editorial.json (excluding the
-- %doc meta key). A typo'd key silently drops an infobox row; this check catches
-- it statically before deployment. The scan covers the whole subtree, not just
-- Vehicle.lua: most :value() calls live in the section sub-builders (Capacity,
-- Cost, Dimensions, Stats, Overview, Lore, Development). Every `:value(` under
-- Vehicle/ is an Editorial.view call, so the bare method name needs no receiver
-- in the pattern.
local VEHICLE_SUBTREE_LABEL = BASE .. '/Vehicle/**.lua'
local vehicleLua = nil
do
	local parts = {}
	local ph = io.popen('find ' .. BASE .. '/Vehicle -name "*.lua" -not -name "testcases.lua"')
	for line in ph:lines() do
		parts[#parts + 1] = readFile(line) or ''
	end
	ph:close()
	vehicleLua = table.concat(parts, '\n')
end
local vehicleEditorial = readJson(VEHICLE_EDITORIAL_PATH)
if vehicleLua ~= '' and vehicleEditorial then
	-- Build a set of declared editorial field names (exclude %doc meta key).
	local editorialFields = {}
	for field, _ in pairs(vehicleEditorial) do
		if type(field) == 'string' and field:sub(1, 1) ~= '%' then
			editorialFields[field] = true
		end
	end

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
	local checked = 0
	for key in vehicleLua:gmatch(":value%('([%w_]+)'") do
		checked = checked + 1
		checkKey(key)
	end
	if checked == 0 then
		fail(VEHICLE_SUBTREE_LABEL, 'found no :value() editorial field reference to check (the idiom moved?)')
	end

	if #missing > 0 then
		for _, k in ipairs(missing) do
			fail(
				VEHICLE_SUBTREE_LABEL,
				"editorial field reference '" .. k .. "' is not declared in " .. VEHICLE_EDITORIAL_PATH
			)
		end
	else
		pass(VEHICLE_SUBTREE_LABEL .. ' (editorial field cross-reference)')
	end
end

-- ── 9. Consumer require-path contract ────────────────────────────────────────
local CONSUMER_REQUIRES = {
	{
		file = 'pages/module/WearableSet/WearableSet.lua',
		need = { 'Module:Entity/Data', 'Module:Entity/Facet/Environment', 'Module:Entity/Facet/Armor' },
	},
	{ file = 'pages/module/Entity/Orders/Orders.lua', need = { 'Module:Entity/Data', 'Module:Entity/Orders/Lines' } },
	{
		file = 'pages/module/Entity/Rewards/Rewards.lua',
		need = { 'Module:Entity/Data', 'Module:Entity/Rewards/Lines' },
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

-- ── 10. emitted-key -> manifest bijection ────────────────────────────────────
-- Known blind spots (don't over-trust this guard):
--   (a) Brand-new SINGLE-WORD keys not yet in the manifest are skipped — a
--       single-word key is only checked once it's already registered, since
--       matching by name alone would flood false positives from single-word
--       locals (m, s, data, ...).
--   (b) Only the `data['prefix_' .. k]` dynamic form is scanned; the inverse
--       `data[var .. '_suffix']` form (used in Armor/Vehicle, currently all
--       registered) is not.
-- New keys of either shape must be registered in properties.json by hand.
local function autoName(key)
	return (key:gsub('_', ' '):gsub('^%l', string.upper))
end
-- Emitter keys composed at runtime (`data['modifier_' .. k]`, Facet/Mining) name
-- no literal in the source, so neither scan can see the property they write.
-- Bucket needs a declared column for each one regardless, so every expansion is
-- a static properties.json entry and only the prefix is registered here: a
-- dynamic prefix nobody registered fails below, and a property under a
-- registered prefix counts as written in 10b.
local DYNAMIC_PREFIXES = { ['modifier_'] = true }
if props then
	local files = {}
	local ph = io.popen('find pages/module/Entity -name "*.lua"')
	for line in ph:lines() do
		files[#files + 1] = line
	end
	ph:close()
	local orphan = {}
	for _, fpath in ipairs(files) do
		local src = readFile(fpath)
		if src then
			for block in src:gmatch('function%s+p%.getStructuredData.-\nend') do
				for key in block:gmatch('([%a_][%w_]*)%s*=') do
					if key:find('_') or type(props[autoName(key)]) == 'table' then
						if type(props[autoName(key)]) ~= 'table' then
							orphan[key] = fpath
						end
					end
				end
			end
			-- The runtime-composed form lives in the helper the hook calls, not in
			-- the hook body, so this one is scanned over the whole file.
			for lit in src:gmatch("data%['([%a_]+)'%s*%.%.") do
				if not DYNAMIC_PREFIXES[lit] then
					orphan[lit .. '*'] = fpath
				end
			end
		end
	end
	local any = false
	for key, fpath in pairs(orphan) do
		fail(
			PROPS_PATH,
			"emitted key '"
				.. key
				.. "' ("
				.. fpath
				.. ') resolves to neither a properties.json entry nor a registered dynamic prefix'
		)
		any = true
	end
	if not any then
		pass(PROPS_PATH .. ' (emitted-key bijection)')
	end
end

-- ── 10b. manifest property -> emitter (the inverse bijection) ────────────────
-- A property nothing writes still costs a Bucket column, which is how the
-- orphaned `Category` survived. Writers live in three places: a
-- getStructuredData block; an editorial manifest entry, whose `property` name
-- Module:Entity/Editorial projects onto the stored data; and the handful below,
-- written outside any hook.
local NON_HOOK_WRITERS = {
	['Manual API field'] = 'Module:Entity/Editorial.toStructuredData',
	['Subject type'] = 'Module:Entity, injected from the resolved typeInfo',
}
if props then
	local emitted, suffixes, prefixes = {}, {}, {}
	for prefix in pairs(DYNAMIC_PREFIXES) do
		prefixes[#prefixes + 1] = autoName(prefix)
	end
	local sources = {}
	local ph = io.popen('find pages/module/Entity -name "*.lua" -o -name "*.json"')
	for line in ph:lines() do
		sources[#sources + 1] = line
	end
	ph:close()
	for _, fpath in ipairs(sources) do
		local src = readFile(fpath)
		if src then
			for block in src:gmatch('function%s+p%.getStructuredData.-\nend') do
				for key in block:gmatch('([%a_][%w_]*)%s*=') do
					emitted[autoName(key)] = true
				end
				for key in block:gmatch("%['([^']+)'%]%s*=") do
					emitted[key] = true
				end
				for suffix in block:gmatch("%.%.%s*'([^']+)'%s*%]") do
					suffixes[#suffixes + 1] = autoName(suffix)
				end
			end
			-- Editorial manifests: Lua field tables and editorial.json alike. Every
			-- entry is one line carrying both `arg` and `property`, which is what
			-- keeps a Store query column ({ property = 'Name', as = 'name' }) from
			-- counting as a writer of that property.
			if fpath ~= PROPS_PATH then
				for line in src:gmatch('[^\n]+') do
					if line:find('arg', 1, true) then
						for name in line:gmatch("property%s*=%s*'([^']+)'") do
							emitted[name] = true
						end
						for name in line:gmatch('"property"%s*:%s*"([^"]+)"') do
							emitted[name] = true
						end
					end
				end
			end
		end
	end
	local function isEmitted(name)
		if emitted[name] or NON_HOOK_WRITERS[name] then
			return true
		end
		for _, suffix in ipairs(suffixes) do
			if name:sub(-#suffix) == suffix then
				return true
			end
		end
		for _, prefix in ipairs(prefixes) do
			if name:sub(1, #prefix) == prefix then
				return true
			end
		end
		return false
	end
	local inverseFailed = false
	for name, def in pairs(props) do
		if type(name) == 'string' and name:sub(1, 1) ~= '%' and type(def) == 'table' then
			if not isEmitted(name) then
				fail(
					PROPS_PATH,
					"property '" .. name .. "' is written by no getStructuredData block or editorial manifest"
				)
				inverseFailed = true
			end
		end
	end
	if not inverseFailed then
		pass(PROPS_PATH .. ' (property-emitter inverse)')
	end
end

-- ── 11. Bucket limits ────────────────────────────────────────────────────────
-- Verified live 2026-09-12: a bucket accepts at most 60 fields; bucket name +
-- field name must not exceed 51 characters (the repeated-field side table
-- bucket__<bucket>__<field> hits MySQL's 64-char identifier cap); a repeated
-- field must be indexed. %kinds lists which buckets each kind may write.
local BUCKET_MAX_FIELDS = 60
local BUCKET_NAME_BUDGET = 51
local function checkBucketLimits(path, manifest)
	if not manifest then
		return
	end
	local limitsFailed = false
	local fields = {} -- bucket -> field -> display name
	local stringBuckets = {} -- bucket -> true, for entries/patterns with a plain string .bucket
	local function place(bucket, field, name, def)
		fields[bucket] = fields[bucket] or {}
		if fields[bucket][field] then
			fail(
				path,
				'bucket '
					.. bucket
					.. ' field '
					.. field
					.. ' is claimed by both '
					.. fields[bucket][field]
					.. ' and '
					.. name
			)
			limitsFailed = true
		end
		fields[bucket][field] = name
		if not ALLOWED_BUCKET_NAMES[bucket] then
			fail(path, 'bucket ' .. bucket .. ' is not an allowed bucket name')
			limitsFailed = true
		end
		if #bucket + #field > BUCKET_NAME_BUDGET then
			fail(
				path,
				'bucket '
					.. bucket
					.. ' field '
					.. field
					.. ' exceeds the '
					.. BUCKET_NAME_BUDGET
					.. '-char bucket+field budget'
			)
			limitsFailed = true
		end
		if def.repeated and not def.index then
			fail(path, 'entry ' .. name .. ' is repeated but not indexed (Bucket requires index on repeated fields)')
			limitsFailed = true
		end
	end
	local function kindListsBucket(kind, bucket)
		local list = manifest['%kinds'][kind]
		for _, b in ipairs(list) do
			if b == bucket then
				return true
			end
		end
		return false
	end
	for name, def in pairs(manifest) do
		if type(name) == 'string' and name:sub(1, 1) ~= '%' and type(def) == 'table' and def.field then
			if type(def.bucket) == 'string' then
				stringBuckets[def.bucket] = true
				place(def.bucket, def.field, name, def)
			elseif type(def.bucket) == 'table' then
				for kind, bucket in pairs(def.bucket) do
					if type(manifest['%kinds']) ~= 'table' or manifest['%kinds'][kind] == nil then
						fail(path, 'entry ' .. name .. ' routes kind ' .. tostring(kind) .. ' which is not in %kinds')
						limitsFailed = true
					elseif not kindListsBucket(kind, bucket) then
						fail(
							path,
							'entry '
								.. name
								.. ' routes kind '
								.. kind
								.. ' to bucket '
								.. bucket
								.. ' which %kinds.'
								.. kind
								.. ' does not list'
						)
						limitsFailed = true
					end
					place(bucket, def.field, name .. ' (' .. kind .. ')', def)
				end
			end
		end
	end
	for bucket, set in pairs(fields) do
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		if n > BUCKET_MAX_FIELDS then
			fail(path, 'bucket ' .. bucket .. ' has ' .. n .. ' fields (max ' .. BUCKET_MAX_FIELDS .. ')')
			limitsFailed = true
		end
	end
	if type(manifest['%kinds']) == 'table' then
		local listedBuckets = {}
		for kind, list in pairs(manifest['%kinds']) do
			for _, bucket in ipairs(list) do
				listedBuckets[bucket] = true
				if fields[bucket] == nil then
					fail(path, '%kinds.' .. kind .. ' names bucket ' .. bucket .. ' which no property uses')
					limitsFailed = true
				end
			end
		end
		for bucket in pairs(stringBuckets) do
			if bucket ~= 'entity' and not listedBuckets[bucket] then
				fail(path, 'bucket ' .. bucket .. ' is written by no kind in %kinds')
				limitsFailed = true
			end
		end
	end
	if not limitsFailed then
		pass(path .. ' (bucket limits)')
	end
end
checkBucketLimits(PROPS_PATH, props)

-- ── 12. Registry kinds all have a %kinds entry ────────────────────────────────
-- %kinds has five keys today only because Registry.kinds happens to list five
-- modules with the same names; nothing checks that the two stay in step. A
-- kind added to the registry without a %kinds entry would silently stop
-- reaching Bucket for every cross-kind property and route the rest of that
-- kind's pages into the unregistered-property tracking category, with no
-- test failing (final-review.md Important 3).
local REGISTRY_PATH = BASE .. '/Registry/Registry.lua'
local function registryKinds(path)
	local src = readFile(path)
	if not src then
		return nil
	end
	local block = src:match('p%.kinds%s*=%s*{(.-)\n}')
	if not block then
		fail(path, 'could not find a p.kinds = { ... } table')
		return nil
	end
	local kinds = {}
	for name in block:gmatch("require%('Module:Entity/([%w_]+)'%)") do
		kinds[#kinds + 1] = name
	end
	return kinds
end
if props then
	local kinds = registryKinds(REGISTRY_PATH)
	if kinds then
		local registryFailed = false
		for _, kind in ipairs(kinds) do
			if type(props['%kinds']) ~= 'table' or type(props['%kinds'][kind]) ~= 'table' then
				fail(REGISTRY_PATH, "kind '" .. kind .. "' is registered but has no properties.json %kinds entry")
				registryFailed = true
			end
		end
		if not registryFailed then
			pass(REGISTRY_PATH .. ' (registry kinds vs %kinds)')
		end
	end
end

-- ── 13. Cross-bucket field-name uniqueness ────────────────────────────────────
-- Module:Entity/Store keeps two buckets' columns apart by selecting a joined
-- one as `bucket.field`, but any consumer that merges rows on the bare field
-- name has one property overwrite the other. A property whose bucket is an
-- object (routed per kind) has one field name, not one per kind, so it is
-- claimed once here.
local function checkFieldNameUniqueness(path, manifest)
	if not manifest then
		return
	end
	local owner = {} -- field name -> display name
	local failed = false
	local function claim(field, name)
		if owner[field] and owner[field] ~= name then
			fail(path, "field '" .. field .. "' is used by both '" .. owner[field] .. "' and '" .. name .. "'")
			failed = true
		else
			owner[field] = name
		end
	end
	for name, def in pairs(manifest) do
		if
			type(name) == 'string'
			and name:sub(1, 1) ~= '%'
			and type(def) == 'table'
			and type(def.field) == 'string'
		then
			claim(def.field, name)
		end
	end
	if not failed then
		pass(path .. ' (field-name uniqueness)')
	end
end
checkFieldNameUniqueness(PROPS_PATH, props)

local COMPANY_PROPS_PATH = 'pages/module/Company/properties.json'
local companyProps = readJson(COMPANY_PROPS_PATH)
if companyProps then
	local cFailed = false
	for name, def in pairs(companyProps) do
		if type(name) == 'string' and name:sub(1, 1) ~= '%' and type(def) == 'table' then
			if type(def.type) ~= 'string' or not ALLOWED_TYPES[def.type] then
				fail(COMPANY_PROPS_PATH, 'entry ' .. name .. ' has invalid .type ' .. tostring(def.type))
				cFailed = true
			end
			if (def.bucket ~= 'company' and def.bucket ~= 'entity') or type(def.field) ~= 'string' then
				fail(COMPANY_PROPS_PATH, 'entry ' .. name .. " must have bucket 'company' or 'entity' and a .field")
				cFailed = true
			end
		end
	end
	-- Company writes an `entity` row (shared with Entity) alongside its own
	-- `company` row; %kinds documents that split for tests/manifest.lua and
	-- Module:Entity/Registry-style cross-checks, though Company.bucketRows
	-- routes by properties.json directly and never consults %kinds at runtime.
	local companyKinds = companyProps['%kinds'] and companyProps['%kinds'].Company
	if type(companyKinds) ~= 'table' or #companyKinds ~= 2 then
		fail(COMPANY_PROPS_PATH, "%kinds.Company must be {'entity', 'company'}")
		cFailed = true
	else
		local wanted = { entity = true, company = true }
		for _, bucket in ipairs(companyKinds) do
			wanted[bucket] = nil
		end
		if next(wanted) ~= nil then
			fail(COMPANY_PROPS_PATH, "%kinds.Company must be {'entity', 'company'}")
			cFailed = true
		end
	end
	if not cFailed then
		pass(COMPANY_PROPS_PATH)
	end
	checkBucketLimits(COMPANY_PROPS_PATH, companyProps)

	-- The `entity` bucket is defined by both Entity/properties.json and
	-- Company/properties.json (Name, Subject type, Image): a field the two
	-- manifests share must agree on type/index/repeated, mirroring
	-- scripts/internal/bucketschemas.Merge. Build the union (one definition per
	-- field; a mismatch fails here instead of being silently shadowed) and run
	-- checkBucketLimits over it so the budget/max-fields checks see both
	-- manifests' contributions to `entity` together.
	local function entityEntries(manifest)
		local out = {}
		for name, def in pairs(manifest) do
			if
				type(name) == 'string'
				and name:sub(1, 1) ~= '%'
				and type(def) == 'table'
				and def.bucket == 'entity'
				and type(def.field) == 'string'
			then
				out[def.field] = { name = name, def = def }
			end
		end
		return out
	end
	local function shapeEquals(a, b)
		return a.type == b.type
			and (a.index or false) == (b.index or false)
			and (a.repeated or false) == (b.repeated or false)
	end

	local entityFromEntity = entityEntries(props)
	local entityFromCompany = entityEntries(companyProps)
	local mergedEntity = {}
	local mergeFailed = false
	for _, entry in pairs(entityFromEntity) do
		mergedEntity[entry.name] = entry.def
	end
	for field, entry in pairs(entityFromCompany) do
		local prev = entityFromEntity[field]
		if prev then
			if not shapeEquals(prev.def, entry.def) then
				fail(
					COMPANY_PROPS_PATH,
					'bucket entity field '
						.. field
						.. ' differs between manifests ('
						.. prev.name
						.. ' vs '
						.. entry.name
						.. ')'
				)
				mergeFailed = true
			end
		else
			mergedEntity[entry.name] = entry.def
		end
	end
	if not mergeFailed then
		pass(COMPANY_PROPS_PATH .. ' (entity bucket merge)')
	end
	checkBucketLimits(COMPANY_PROPS_PATH .. ' + ' .. PROPS_PATH .. ' (merged entity)', mergedEntity)

	local WEARABLESET_PROPS_PATH = 'pages/module/WearableSet/properties.json'
	local wearableSetProps = readJson(WEARABLESET_PROPS_PATH)
	if wearableSetProps then
		local wsFailed = false
		for name, def in pairs(wearableSetProps) do
			if type(name) == 'string' and name:sub(1, 1) ~= '%' and type(def) == 'table' then
				if type(def.type) ~= 'string' or not ALLOWED_TYPES[def.type] then
					fail(WEARABLESET_PROPS_PATH, 'entry ' .. name .. ' has invalid .type ' .. tostring(def.type))
					wsFailed = true
				end
				if (def.bucket ~= 'wearable_set' and def.bucket ~= 'entity') or type(def.field) ~= 'string' then
					fail(
						WEARABLESET_PROPS_PATH,
						'entry ' .. name .. " must have bucket 'wearable_set' or 'entity' and a .field"
					)
					wsFailed = true
				end
			end
		end
		-- WearableSet writes an `entity` row (shared with Entity and Company)
		-- alongside its own `wearable_set` row; %kinds documents that split the
		-- same way Company's does, though WearableSet.bucketRows routes by
		-- properties.json directly and never consults %kinds at runtime.
		local wsKinds = wearableSetProps['%kinds'] and wearableSetProps['%kinds']['Wearable set']
		if type(wsKinds) ~= 'table' or #wsKinds ~= 2 then
			fail(WEARABLESET_PROPS_PATH, "%kinds['Wearable set'] must be {'entity', 'wearable_set'}")
			wsFailed = true
		else
			local wanted = { entity = true, wearable_set = true }
			for _, bucket in ipairs(wsKinds) do
				wanted[bucket] = nil
			end
			if next(wanted) ~= nil then
				fail(WEARABLESET_PROPS_PATH, "%kinds['Wearable set'] must be {'entity', 'wearable_set'}")
				wsFailed = true
			end
		end
		if not wsFailed then
			pass(WEARABLESET_PROPS_PATH)
		end
		checkBucketLimits(WEARABLESET_PROPS_PATH, wearableSetProps)

		-- The `entity` bucket is defined by three manifests: fold
		-- WearableSet's contribution into the Entity+Company merge above (a
		-- field it shares with either must agree on type/index/repeated too)
		-- and re-check the three-way union.
		local entityFromWearableSet = entityEntries(wearableSetProps)
		local knownEntity = {}
		for field, entry in pairs(entityFromEntity) do
			knownEntity[field] = entry
		end
		for field, entry in pairs(entityFromCompany) do
			knownEntity[field] = entry
		end
		local threeWayFailed = false
		for field, entry in pairs(entityFromWearableSet) do
			local prev = knownEntity[field]
			if prev then
				if not shapeEquals(prev.def, entry.def) then
					fail(
						WEARABLESET_PROPS_PATH,
						'bucket entity field '
							.. field
							.. ' differs between manifests ('
							.. prev.name
							.. ' vs '
							.. entry.name
							.. ')'
					)
					threeWayFailed = true
				end
			else
				mergedEntity[entry.name] = entry.def
			end
		end
		if not threeWayFailed then
			pass(WEARABLESET_PROPS_PATH .. ' (entity bucket merge)')
		end
		checkBucketLimits(
			COMPANY_PROPS_PATH .. ' + ' .. PROPS_PATH .. ' + ' .. WEARABLESET_PROPS_PATH .. ' (merged entity)',
			mergedEntity
		)
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
