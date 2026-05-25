require('strict')

--- @module Entity/Ports/Pipeline
--- Pure data transformations for Entity/Ports. Takes raw API ports,
--- returns render-ready aggregated groups. Knows nothing about HTML.
---
--- Public API is a single entry point: `pipeline.process(rawPorts, opts)`.
--- Internal stages are exposed under `pipeline._internal` for testing
--- but are NOT part of the contract — call sites should use process().
---
--- Pipeline stages, in order:
---   1. normalize  — flatten API shape into normalized port nodes
---   2. clean      — drop collapsed-category children from each node's subtree
---   3. narrow     — vehicle-only: drop child types not in parent's expandIntoTypes
---   4. aggregate  — collapse identical-signature siblings; pre-compute `expandable`
---   5. group      — bucket into primary cards + one "Other" card with sub-groups

local categories = require('Module:Entity/Ports/Categories')

local p = {}

local LOC_EMPTY = '@LOC_EMPTY'
-- Defensive recursion guard. Real data tops out at depth 4.
local MAX_DEPTH = 4

--- Apiunto puts placeholder text in equipped-item names sometimes
--- ("<= PLACEHOLDER =>"). Fall back to `class_name`, then to a generic
--- "Unknown item". When the resolved name is a placeholder, suppress
--- the wikilink so we don't redlink to nonsense titles.
---
--- @param equipped table|nil
--- @return { name: string, pageLink: string, size: number|nil }|nil
local function equippedItemDisplay(equipped)
	if type(equipped) ~= 'table' then
		return nil
	end
	local raw = equipped.name
	local size = tonumber(equipped.size)
	local isPlaceholder = type(raw) ~= 'string' or raw == '' or raw:find('PLACEHOLDER', 1, true) ~= nil
	if isPlaceholder then
		local fallback = (type(equipped.class_name) == 'string' and equipped.class_name ~= '') and equipped.class_name
			or 'Unknown item'
		return { name = fallback, pageLink = '', size = size }
	end
	return { name = raw, pageLink = '[[' .. raw .. ']]', size = size }
end

--- A docking port (a `DockingCollar` with a craft docked) carries the
--- docked vehicle in `attached_vehicle`, while its own `equipped_item` is
--- the docking-tube hardware — whose name is a placeholder, so the plain
--- equipped display would surface a raw class_name like
--- `DRAK_Caterpillar_Command_Module_DockingTube`. Render the docked
--- vehicle instead: its clean name, size from `size_class`, and its uuid
--- for canonical-page resolution. Returns nil when no craft is docked.
---
--- @param rawPort table
--- @return ({ name: string, pageLink: string, size: number|nil }|nil) display
--- @return string|nil uuid  the docked vehicle's uuid, for link resolution
local function attachedVehicleDisplay(rawPort)
	local av = rawPort.attached_vehicle
	if type(av) ~= 'table' then
		return nil, nil
	end
	local name = av.name
	if type(name) ~= 'string' or name == '' then
		return nil, nil
	end
	local uuid = type(av.uuid) == 'string' and av.uuid or nil
	return { name = name, pageLink = '[[' .. name .. ']]', size = tonumber(av.size_class) }, uuid
end

--- Picks the best display label for a port: prefer `display_name`
--- when it's a real string (not the engine's `@LOC_EMPTY` sentinel),
--- otherwise fall back to the raw `name`. No prettification — the raw
--- names (e.g. `BAR1`, `MEC`, `POW`, `VEN`) are recognizable as-is and
--- prettifying them would mangle the acronyms (`Bar1`, `Mec`, …).
---
--- @param rawPort table
--- @return string
local function resolveDisplayName(rawPort)
	local dn = rawPort.display_name
	if type(dn) == 'string' and dn ~= '' and dn ~= LOC_EMPTY then
		return dn
	end
	return rawPort.name or ''
end

--- Expands `port.compatible_types` (`{ { type, sub_types[] }, … }`) into
--- a flat list of "Type.SubType" strings (or "Type" when sub_types is
--- empty). Used to derive a category fallback when the port's own
--- `type` field is empty (CIG leaves it blank on some cooler /
--- power-plant / shield mounts).
---
--- @param rawPort table
--- @return string[]
local function collectCompatibleTypes(rawPort)
	local out = {}
	local list = rawPort.compatible_types
	if type(list) ~= 'table' then
		return out
	end
	for _, entry in ipairs(list) do
		local t = type(entry) == 'table' and entry.type or nil
		if type(t) == 'string' and t ~= '' then
			local subs = entry.sub_types
			if type(subs) == 'table' and #subs > 0 then
				for _, s in ipairs(subs) do
					table.insert(out, t .. '.' .. tostring(s))
				end
			else
				table.insert(out, t)
			end
		end
	end
	return out
end

--- Walks one raw port node and returns its normalized form, recursing
--- into the child `ports` array. Returns nil when the port should be
--- skipped entirely (engine-internal mounts with no compat types and
--- no equipped item).
---
--- @param rawPort table
--- @param depth integer|nil
--- @return table|nil
local function normalizePort(rawPort, depth)
	depth = depth or 1
	if type(rawPort) ~= 'table' then
		return nil
	end
	local compatibleTypes = collectCompatibleTypes(rawPort)
	local equipped = rawPort.equipped_item
	local attachedItem, attachedUuid = attachedVehicleDisplay(rawPort)
	if #compatibleTypes == 0 and equipped == nil and not attachedItem then
		return nil
	end

	local sizeMin, sizeMax
	if type(rawPort.sizes) == 'table' then
		sizeMin = tonumber(rawPort.sizes.min)
		sizeMax = tonumber(rawPort.sizes.max)
	end
	if not sizeMin then
		sizeMin = tonumber(rawPort.size) or 0
	end
	if not sizeMax then
		sizeMax = tonumber(rawPort.size) or sizeMin
	end

	-- Apiunto v3 puts child ports at `port.ports` (a sibling of equipped_item).
	-- Older / item-endpoint responses may have used `equipped_item.ports` instead;
	-- fall back to that when the v3 location is empty.
	local childPorts
	if type(rawPort.ports) == 'table' and #rawPort.ports > 0 then
		childPorts = rawPort.ports
	elseif type(equipped) == 'table' and type(equipped.ports) == 'table' then
		childPorts = equipped.ports
	end

	-- A docked vehicle's own ports (the collar's `attached_vehicle`
	-- internals: fuel/relay/screen mounts) are noise on the carrier's
	-- page — the docked craft has its own page for its loadout. Skip
	-- them so the Docked Vehicles row is a clean leaf.
	local children = {}
	if not attachedItem and depth < MAX_DEPTH and type(childPorts) == 'table' then
		for _, child in ipairs(childPorts) do
			local n = normalizePort(child, depth + 1)
			if n then
				table.insert(children, n)
			end
		end
	end

	local editable
	if rawPort.editable == nil then
		editable = true
	else
		editable = rawPort.editable == true
	end

	local node = {
		name = rawPort.name or '',
		displayName = resolveDisplayName(rawPort),
		sizeMin = sizeMin,
		sizeMax = sizeMax,
		type = type(rawPort.type) == 'string' and rawPort.type or '',
		subType = (type(rawPort.sub_type) == 'string' and rawPort.sub_type)
			or (type(rawPort.subtype) == 'string' and rawPort.subtype)
			or '',
		category = categories.lookup(categories.deriveLabel(rawPort, compatibleTypes)),
		compatibleTypes = compatibleTypes,
		editable = editable,
		equippedItem = attachedItem or equippedItemDisplay(equipped),
		children = children,
	}
	if attachedUuid then
		node._equippedUuid = attachedUuid
	elseif type(rawPort.equipped_item_uuid) == 'string' then
		node._equippedUuid = rawPort.equipped_item_uuid
	end
	return node
end

--- Walks a raw top-level ports array.
--- @param rawPorts table[]|nil
--- @return table[]
local function normalizePorts(rawPorts)
	local out = {}
	if type(rawPorts) ~= 'table' then
		return out
	end
	for _, raw in ipairs(rawPorts) do
		local n = normalizePort(raw, 1)
		if n then
			table.insert(out, n)
		end
	end
	return out
end

--- Returns true when a port belongs to a category flagged
--- `collapsed:true` in categories.json (engine / cockpit / animation
--- hardpoints that hide inside the "Other" card rather than crowding
--- primary cards). Bare port nodes without a `category` field are
--- treated as collapsed; this matters for tests that bypass
--- `normalizePort`.
---
--- @param port table  normalized port node; reads `port.category`
--- @return boolean
local function isCollapsedCategory(port)
	return port.category == nil or port.category.collapsed == true
end

--- Recursively drops collapsed-category nodes from a normalized port
--- tree. Returns a fresh array; does not mutate the input.
---
--- @param nodes table[]
--- @return table[]
local function filterPorts(nodes)
	local out = {}
	if type(nodes) ~= 'table' then
		return out
	end
	for _, node in ipairs(nodes) do
		if not isCollapsedCategory(node) then
			local kept = {
				name = node.name,
				displayName = node.displayName,
				type = node.type,
				subType = node.subType,
				sizeMin = node.sizeMin,
				sizeMax = node.sizeMax,
				category = node.category,
				compatibleTypes = node.compatibleTypes,
				editable = node.editable,
				equippedItem = node.equippedItem,
				children = filterPorts(node.children),
			}
			if node._equippedUuid then
				kept._equippedUuid = node._equippedUuid
			end
			table.insert(out, kept)
		end
	end
	return out
end

--- Strips collapsed nodes from each node's CHILDREN recursively, but
--- leaves the top-level nodes themselves in place regardless of their
--- own collapsed status. Top-level collapsed nodes route into the
--- "Other" card — they need to survive this step so they can be
--- displayed inside that card.
---
--- @param nodes table[]
--- @return table[]
local function cleanChildren(nodes)
	local out = {}
	if type(nodes) ~= 'table' then
		return out
	end
	for _, node in ipairs(nodes) do
		local kept = {}
		for k, v in pairs(node) do
			kept[k] = v
		end
		kept.children = filterPorts(node.children)
		table.insert(out, kept)
	end
	return out
end

--- Vehicle-only: recursively narrows each node's children to those
--- whose `type` is in the parent category's `expandIntoTypes`
--- allowlist. When a parent has no allowlist, children pass through
--- unchanged. Drops Display / Interactable / cockpit noise from
--- Turret children. Items skip this step.
---
--- @param nodes table[]
--- @return table[]
local function narrowChildren(nodes)
	local out = {}
	if type(nodes) ~= 'table' then
		return out
	end
	for _, node in ipairs(nodes) do
		local kept = {}
		for k, v in pairs(node) do
			kept[k] = v
		end
		local allow = node.category and node.category.expandIntoTypes
		local children = node.children
		if allow and type(children) == 'table' then
			local narrowed = {}
			for _, child in ipairs(children) do
				local childType = child.type or ''
				for _, allowedType in ipairs(allow) do
					if childType == allowedType then
						table.insert(narrowed, child)
						break
					end
				end
			end
			children = narrowed
		end
		kept.children = narrowChildren(children)
		table.insert(out, kept)
	end
	return out
end

--- Computes a stable, recursive signature for a port node. Two nodes
--- with the same signature are "structurally identical" for
--- aggregation — same type/subType, same sizes, same equipped item,
--- same editability, same recursive child structure, AND same
--- accepted compatible_types.
---
--- The compat_types factor matters for ports like M4A Cannon's
--- BAR/MEC/POW/VEN attachment slots — all `type=""` but each
--- accepting a different sub_type. They must NOT aggregate.
---
--- Insensitive to instance-level fields (name, displayName,
--- _equippedUuid) so two turrets in different ship locations with the
--- same loadout produce the same signature.
---
--- @param node table
--- @return string
local function signatureFor(node)
	local parts = {
		node.type or '',
		node.subType or '',
		tostring(node.sizeMin or ''),
		tostring(node.sizeMax or ''),
		(node.equippedItem and node.equippedItem.name) or '',
		tostring(node.editable),
	}
	if type(node.compatibleTypes) == 'table' and #node.compatibleTypes > 0 then
		local sortedCompat = {}
		for _, t in ipairs(node.compatibleTypes) do
			table.insert(sortedCompat, t)
		end
		table.sort(sortedCompat)
		table.insert(parts, '<' .. table.concat(sortedCompat, ',') .. '>')
	end
	if type(node.children) == 'table' and #node.children > 0 then
		local childSigs = {}
		for _, child in ipairs(node.children) do
			table.insert(childSigs, signatureFor(child))
		end
		table.sort(childSigs)
		table.insert(parts, '[' .. table.concat(childSigs, ',') .. ']')
	end
	return table.concat(parts, '|')
end

--- Returns true when the node's category opts into child-tree
--- expansion (has a non-empty `expandIntoTypes` allowlist).
---
--- Note: checks `allow[1] ~= nil` rather than `#allow > 0` because
--- `mw.loadJsonData` returns frozen tables where the `#` operator
--- reports length 0 even on populated array sub-tables.
---
--- @param node table  normalized port node
--- @return boolean
local function computeExpandable(node)
	if node.category == nil then
		return false
	end
	local allow = node.category.expandIntoTypes
	return type(allow) == 'table' and allow[1] ~= nil
end

--- Collapses identical-signature siblings into aggregated entries.
--- Each output entry holds `count`, a `representative` (one of the
--- originals — used for all display attrs), a recursively-aggregated
--- `children` list, and a pre-computed `expandable` boolean (Render
--- consumes this directly instead of inspecting category internals).
---
--- Distinct groups are emitted in first-occurrence order so the
--- relative position of port groups in the API response is preserved.
---
--- @param nodes table[]  normalized sibling port nodes
--- @return table[]  aggregated nodes
local function aggregateSiblings(nodes)
	local groups = {}
	local order = {}
	if type(nodes) ~= 'table' then
		return {}
	end
	for _, node in ipairs(nodes) do
		local key = signatureFor(node)
		if groups[key] then
			groups[key].count = groups[key].count + 1
		else
			groups[key] = {
				count = 1,
				representative = node,
				children = aggregateSiblings(node.children or {}),
				expandable = computeExpandable(node),
			}
			table.insert(order, key)
		end
	end
	local out = {}
	for _, key in ipairs(order) do
		table.insert(out, groups[key])
	end
	return out
end

--- Buckets aggregated top-level nodes into one primary card per
--- distinct category label, plus a single "Other" card at the
--- bottom that sub-groups every collapsed-category node by its
--- original label.
---
--- Primary cards sort by `order` ASC then `label` ASC. The "Other"
--- card always sorts last and renders closed by default; its
--- `subGroups` carry the per-label sub-sections so the reader can
--- still tell which collapsed bucket each row came from.
---
--- @param aggregatedTopLevel table[]
--- @return table[]  groups, in render order
local function groupByCategory(aggregatedTopLevel)
	local primary = {}
	local otherSubMap = {}
	local otherSubOrder = {}
	local otherRows = {}
	for _, agg in ipairs(aggregatedTopLevel) do
		local cat = agg.representative.category
		if cat.collapsed then
			table.insert(otherRows, agg)
			local lbl = cat.label
			if not otherSubMap[lbl] then
				otherSubMap[lbl] = { label = lbl, rows = {} }
				table.insert(otherSubOrder, lbl)
			end
			table.insert(otherSubMap[lbl].rows, agg)
		else
			local label = cat.label
			if not primary[label] then
				-- First occurrence wins for `order`. Assumes shared labels in
				-- categories.json agree on order — disagreement is silent here.
				primary[label] = { label = label, order = cat.order, collapsed = false, rows = {} }
			end
			table.insert(primary[label].rows, agg)
		end
	end
	local ordered = {}
	for _, g in pairs(primary) do
		table.insert(ordered, g)
	end
	table.sort(ordered, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.label < b.label
	end)
	if #otherRows > 0 then
		local subGroups = {}
		for _, lbl in ipairs(otherSubOrder) do
			table.insert(subGroups, otherSubMap[lbl])
		end
		table.insert(ordered, {
			label = 'Other',
			order = 1000,
			collapsed = true,
			rows = otherRows,
			subGroups = subGroups,
		})
	end
	return ordered
end

--- Runs the full pipeline: normalize → clean → narrow (vehicles only)
--- → aggregate → group. Returns the render-ready groups array.
---
--- Output shape (the Pipeline → Render contract):
---   groups[] = { label, order, collapsed, rows[], subGroups[]? }
---   rows[i]  = { count, expandable, representative, children[] }
--- See README.md "Data contract (Pipeline → Render)" section for the
--- full shape spec.
---
--- @param rawPorts table[]|nil  the API's `data.ports`
--- @param opts { isVehicle: boolean }|nil
--- @return table[]  groups, ready for Render.fromGroups
function p.process(rawPorts, opts)
	opts = opts or {}
	local normalized = normalizePorts(rawPorts)
	local cleaned = cleanChildren(normalized)
	if opts.isVehicle then
		cleaned = narrowChildren(cleaned)
	end
	return groupByCategory(aggregateSiblings(cleaned))
end

--- Collects the distinct equipped-item UUIDs from a processed group tree
--- (the output of p.process), for batch page resolution. Walks each group's
--- rows and their nested children. The "Other" group's subGroups reference
--- the same row objects, so walking `rows` alone covers them.
---
--- @param groups table[]  output of p.process
--- @return string[]  distinct equipped UUIDs, in first-seen order
function p.collectEquippedUuids(groups)
	local out, seen = {}, {}
	local function walk(entry)
		local node = entry.representative
		local uuid = node and node._equippedUuid
		if type(uuid) == 'string' and not seen[uuid] then
			seen[uuid] = true
			table.insert(out, uuid)
		end
		for _, child in ipairs(entry.children or {}) do
			walk(child)
		end
	end
	for _, group in ipairs(groups or {}) do
		for _, row in ipairs(group.rows or {}) do
			walk(row)
		end
	end
	return out
end

--- Rewrites equipped-item links in place from a {uuid -> {page}} map (from
--- PageResolver.resolve). For a resolved UUID, links to the canonical page
--- with the friendly item name as the label; when the name was a placeholder
--- (link previously suppressed to ''), uses the page as the label. Unresolved
--- UUIDs are left untouched, keeping the existing name-based fallback link.
---
--- @param groups table[]  output of p.process (mutated in place)
--- @param map table<string, { page: string, image: string|nil }>
function p.applyResolvedLinks(groups, map)
	local function walk(entry)
		local node = entry.representative
		local item = node and node.equippedItem
		local uuid = node and node._equippedUuid
		if item and type(uuid) == 'string' and map[uuid] and map[uuid].page then
			local page = map[uuid].page
			if item.pageLink == '' then
				item.pageLink = '[[' .. page .. ']]'
			else
				item.pageLink = '[[' .. page .. '|' .. item.name .. ']]'
			end
		end
		for _, child in ipairs(entry.children or {}) do
			walk(child)
		end
	end
	for _, group in ipairs(groups or {}) do
		for _, row in ipairs(group.rows or {}) do
			walk(row)
		end
	end
end

-- Test-only exports. Not part of the public API.
-- Only helpers actually exercised by Pipeline/testcases.lua. Add to
-- this list when a new test demands access — don't widen pre-emptively.
p._internal = {
	equippedItemDisplay = equippedItemDisplay,
	normalizePort = normalizePort,
	isCollapsedCategory = isCollapsedCategory,
	filterPorts = filterPorts,
	narrowChildren = narrowChildren,
	signatureFor = signatureFor,
	aggregateSiblings = aggregateSiblings,
	groupByCategory = groupByCategory,
}

return p
