require('strict')

--- @module Entity/Assembly
--- Composition primitives that assemble an entity from its component chain and
--- facets: walk the p.parent chain, and merge the ordered section lists / flat
--- structured-data tables / category lists / editorial manifests each component contributes. All pure.

local p = {}

--- Merges a list of ordered section lists into a single ordered list of sections.
--- For matching keys, items are appended. First definition's metadata (label, collapsible, etc.) wins.
--- Display order is determined by the order entries appear across the input lists.
---
--- Each entry in the input lists is a table with a 'key' field and section data fields.
--- Example: { key = 'general', label = 'General', items = { ... } }
---
--- @param sectionsList table[][] List of ordered section lists from each module in the chain
--- @return table[] Ordered list of merged sections
function p.mergeSections(sectionsList)
	local order = {}
	local seen = {}
	local merged = {}

	for _, sections in ipairs(sectionsList) do
		for _, section in ipairs(sections) do
			local key = section.key

			if not seen[key] then
				seen[key] = true
				table.insert(order, key)
				merged[key] = {
					label = section.label,
					collapsible = section.collapsible,
					collapsed = section.collapsed,
					columns = section.columns,
					class = section.class,
					content = section.content,
					sections = section.sections,
					items = {},
				}
			end

			if section.items then
				for _, item in ipairs(section.items) do
					table.insert(merged[key].items, item)
				end
			end
		end
	end

	local result = {}
	for _, key in ipairs(order) do
		local section = merged[key]
		if #section.items == 0 then
			section.items = nil
		end
		-- Drop sections with nothing to show (e.g. Base's old empty 'general'
		-- scaffold on a kind that uses a different section key) so they don't
		-- render as a stray empty section block.
		if section.items or section.content or section.sections then
			table.insert(result, section)
		end
	end

	return result
end

--- Merges a list of flat key-value tables. Later tables override earlier ones on key collision.
---
--- @param dataList table[] List of structured data tables from each module in the chain
--- @return table Merged key-value table
function p.mergeStructuredData(dataList)
	local result = {}
	for _, data in ipairs(dataList) do
		for k, v in pairs(data) do
			result[k] = v
		end
	end
	return result
end

--- Walks p.parent from a leaf module up to the root, returns the chain in root-first order.
---
--- @param leafModule table The leaf type module (e.g. WeaponGun)
--- @return table[] List of modules from root (Base) to leaf (WeaponGun)
function p.buildChain(leafModule)
	local chain = { leafModule }
	local current = leafModule

	while current.parent do
		current = require('Module:' .. current.parent)
		table.insert(chain, current)
	end

	-- Reverse to get root-first order
	local reversed = {}
	for i = #chain, 1, -1 do
		table.insert(reversed, chain[i])
	end

	return reversed
end

--- Caller must check the hook exists first — a defined hook returning nil is a real answer for resolveMostSpecific.
--- @param mod table A chain link or facet
--- @param hookName string
--- @param ctx EntityHookContext
--- @return any
function p.callHook(mod, hookName, ctx)
	return mod[hookName](ctx)
end

--- Walks `chain` leaf-first (chain[#chain]..chain[1]); returns the first link's
--- `hookName` result accepted by `accept`. nil when none qualifies. Pure.
--- @param chain table[] Root-first chain (walked in reverse)
--- @param hookName string
--- @param accept nil|fun(result: any): boolean Default: any (first defining link wins, even on nil)
--- @param ctx EntityHookContext
--- @return any
function p.resolveMostSpecific(chain, hookName, accept, ctx)
	for i = #chain, 1, -1 do
		if chain[i][hookName] then
			local result = p.callHook(chain[i], hookName, ctx)
			if accept == nil or accept(result) then
				return result
			end
		end
	end
	return nil
end

--- Accept predicate for fields that ignore a nil-or-empty contribution and keep
--- walking (subtitle, header badge).
--- @param result any
--- @return boolean
function p.acceptNonEmpty(result)
	return result ~= nil and result ~= ''
end

--- Additive policy: calls `hookName` on every link that defines it, root to
--- leaf, and concatenates the returned lists. A link without the hook, or one
--- returning nil or a non-table, contributes nothing. Pure.
--- @param chain table[] Root-first chain
--- @param hookName string
--- @param ctx EntityHookContext
--- @return any[]
function p.collect(chain, hookName, ctx)
	local out = {}
	for _, link in ipairs(chain) do
		local hook = link[hookName]
		if hook then
			local items = p.callHook(link, hookName, ctx)
			if type(items) == 'table' then
				for _, item in ipairs(items) do
					out[#out + 1] = item
				end
			end
		end
	end
	return out
end

--- Merge policy for getEditorialManifest: every link's fragment folded root to
--- leaf into one fresh table, so a leaf redefining a field wins. Returns nil
--- when no link defines a manifest that is a table — the signal that the page
--- has no editorial layer at all, distinct from an empty one. Fragments are
--- copied shallowly; a mw.loadJsonData fragment (Vehicle's) is read-only, so
--- nothing writes into it.
--- @param chain table[] Root-first chain
--- @return table|nil
function p.mergeEditorialManifests(chain)
	local merged = nil
	for _, link in ipairs(chain) do
		if link.getEditorialManifest then
			local fragment = link.getEditorialManifest()
			if type(fragment) == 'table' then
				merged = merged or {}
				for field, def in pairs(fragment) do
					merged[field] = def
				end
			end
		end
	end
	return merged
end

--- How each hook's answers combine across a root-first chain, or across the
--- facet list in registry order. The one place a hook's policy lives: callers
--- go through p.run, and Module:Entity/Assembly/testcases fails when a hook
--- Module:Entity/Contract declares has no policy here.
---
--- - collect: every link's list, concatenated root to leaf
--- - merge: every link's table, merged root to leaf, later keys winning
--- - pipeline: each link's answer becomes ctx.apiData for the next
--- - leaf: the last link's answer alone; an ancestor's is never asked
--- - mostSpecific: the most specific link defining the hook, even when it answers nil
--- - mostSpecificNonEmpty: the most specific nil-or-empty-skipping answer
--- - firstNonNil: the first answer in list order that is not nil
--- - fold: editorial manifest fragments merged by mergeEditorialManifests
--- @type table<string, string>
p.POLICIES = {
	getSections = 'collect',
	getExternalSiteItems = 'collect',
	getFooterButtons = 'collect',
	getMetadataItems = 'collect',
	getCategories = 'collect',
	getApiConfigs = 'collect',
	getStructuredData = 'merge',
	enrich = 'pipeline',
	getTypeInfo = 'leaf',
	getShortDescription = 'mostSpecific',
	getAcquisition = 'mostSpecific',
	getBlueprints = 'mostSpecific',
	getPorts = 'mostSpecific',
	getSubtitle = 'mostSpecificNonEmpty',
	getTitleAnnotation = 'mostSpecificNonEmpty',
	getHeaderBadge = 'mostSpecificNonEmpty',
	getRelated = 'mostSpecificNonEmpty',
	getShortDescriptionPrefix = 'firstNonNil',
	getEditorialManifest = 'fold',
}

--- Asks every link in `list` that defines `hookName` and combines the answers
--- by the hook's policy in p.POLICIES. Errors for a hook with no policy, so a
--- new hook fails where it is first called rather than combining by guesswork.
--- @param list table[] Root-first chain, or the facet list
--- @param hookName string
--- @param ctx EntityHookContext|nil Unused by `fold`
--- @return any
function p.run(list, hookName, ctx)
	local policy = p.POLICIES[hookName]
	if policy == 'collect' then
		return p.collect(list, hookName, ctx)
	elseif policy == 'merge' then
		local merged = {}
		for _, link in ipairs(list) do
			if link[hookName] then
				local data = p.callHook(link, hookName, ctx)
				if type(data) == 'table' then
					for k, v in pairs(data) do
						merged[k] = v
					end
				end
			end
		end
		return merged
	elseif policy == 'pipeline' then
		for _, link in ipairs(list) do
			if link[hookName] then
				ctx.apiData = p.callHook(link, hookName, ctx)
			end
		end
		return ctx.apiData
	elseif policy == 'leaf' then
		local leaf = list[#list]
		if leaf and leaf[hookName] then
			return p.callHook(leaf, hookName, ctx)
		end
		return nil
	elseif policy == 'mostSpecific' then
		return p.resolveMostSpecific(list, hookName, nil, ctx)
	elseif policy == 'mostSpecificNonEmpty' then
		return p.resolveMostSpecific(list, hookName, p.acceptNonEmpty, ctx)
	elseif policy == 'firstNonNil' then
		for _, link in ipairs(list) do
			if link[hookName] then
				local answer = p.callHook(link, hookName, ctx)
				if answer ~= nil then
					return answer
				end
			end
		end
		return nil
	elseif policy == 'fold' then
		return p.mergeEditorialManifests(list)
	end
	error("Assembly.run: no policy for hook '" .. tostring(hookName) .. "'")
end

return p
