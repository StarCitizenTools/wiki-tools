require('strict')

--- @module Entity/Contract
--- The Entity component contract as data + a checker. Defines, per role, which
--- lifecycle hooks exist and which are required, and validates a component
--- module against a role. Used by the registry conformance test so a mis-wired
--- kind or facet fails a unit test rather than silently no-opping on-wiki.
---
--- Roles: CONTRIBUTOR (every chain link), KIND (identity + contributor), FACET.

local p = {}

--- Contributor: the hook set every chain link (Base, a kind, a subtype leaf)
--- may implement. Every hook is optional — a link implements only what it
--- adds. Module:Entity/Data applies one merge policy per hook: sections,
--- structured data, external sites, metadata rows, footer buttons and
--- categories are additive root-to-leaf; enrich runs root-to-leaf, each link
--- receiving the previous link's apiData; the editorial manifest merges
--- root-to-leaf with leaf keys winning; type info, short description,
--- subtitle, header badge and acquisition are leaf-first-wins.
--- @type table<string, boolean>
p.CONTRIBUTOR = {
	getSections = false,
	getStructuredData = false,
	getShortDescription = false,
	getExternalSiteItems = false,
	getFooterButtons = false,
	getMetadataItems = false,
	getTypeInfo = false,
	getApiConfigs = false,
	getSubtitle = false,
	getHeaderBadge = false,
	enrich = false,
	getEditorialManifest = false,
	getCategories = false,
	getAcquisition = false,
}

--- Chain link is the contributor role under its older name; kept so existing
--- callers (the Location leaf conformance test) keep validating.
p.CHAIN_LINK = p.CONTRIBUTOR

--- Kind identity: what a registered kind owns beyond being a contributor.
--- `matches` + `getApiConfigs` identify it (the probe and the declared-kind
--- gate); `resolveSubtype` refines it to a leaf.
--- @type table<string, boolean>
p.KIND_IDENTITY = {
	matches = true,
	getApiConfigs = true,
	resolveSubtype = false,
}

--- Kind: identity plus every contributor hook, built from the two specs so the
--- three can never drift. getApiConfigs is required here (identity) even
--- though a plain contributor may omit it.
--- @type table<string, boolean>
p.KIND = {}
for hook, required in pairs(p.CONTRIBUTOR) do
	p.KIND[hook] = required
end
for hook, required in pairs(p.KIND_IDENTITY) do
	p.KIND[hook] = required
end

--- Non-function KIND fields with declared scalar types. validate() rejects any
--- non-function spec key, so typed scalar fields — the canonical kind `name` and
--- the `editorialMode` opt-in — live here and are checked by validateFields(),
--- run alongside validate() by the Registry conformance test.
--- @type table<string, { type: string, required: boolean }>
p.KIND_FIELDS = {
	name = { type = 'string', required = true },
	editorialMode = { type = 'boolean', required = false },
}

--- Facet: a cross-cutting additive aspect matched on a data field.
--- @type table<string, boolean>
p.FACET = {
	matches = true,
	getSections = true,
	getStructuredData = false,
	getShortDescriptionPrefix = false,
}

--- Union of every hook name across all role specs; used by validate()'s strict
--- pass to distinguish a misspelled hook from one valid in a different role.
--- @type table<string, boolean>
p.ALL_HOOKS = {}
for _, spec in ipairs({ p.KIND, p.FACET, p.CHAIN_LINK }) do
	for hook in pairs(spec) do
		p.ALL_HOOKS[hook] = true
	end
end

--- Validates a component against a role spec. Each required hook must be present
--- and a function; each present spec-hook must be a function. Unknown keys are
--- not flagged (modules expose legitimate public helpers), so a misspelled
--- optional hook is not caught — required hooks are.
---
--- "Required" means the role is inert without that hook (the conformance gate),
--- NOT that a caller throws — Entity.lua still guards each call with `if mod.x`.
--- The contract is deliberately stricter than the lenient runtime: a facet with
--- no getSections wouldn't crash, but it would do nothing, so it's a wiring bug.
---
--- @param component table The module to check
--- @param spec table<string, boolean> A role spec (p.KIND / p.FACET / p.CHAIN_LINK)
--- @param options nil|{ strict: boolean } When strict, also flag component keys that look like a misspelled hook (a function whose name is not in spec and not in p.ALL_HOOKS). Default: off (byte-identical to the pre-PR1 behavior).
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validate(component, spec, options)
	if type(component) ~= 'table' then
		return false, { 'component is not a table (got ' .. type(component) .. ')' }
	end
	local errors = {}
	for hook, required in pairs(spec) do
		local value = component[hook]
		if value == nil then
			if required then
				table.insert(errors, 'missing required hook: ' .. hook)
			end
		elseif type(value) ~= 'function' then
			table.insert(errors, 'hook is not a function: ' .. hook .. ' (got ' .. type(value) .. ')')
		end
	end
	if options and options.strict then
		for key, value in pairs(component) do
			if
				type(value) == 'function'
				and spec[key] == nil
				and not p.ALL_HOOKS[key]
				and (key:find('^get') or key == 'matches' or key == 'resolveSubtype' or key == 'enrich')
			then
				table.insert(errors, 'unknown hook (typo?): ' .. key)
			end
		end
	end
	return #errors == 0, errors
end

--- Validates a component's non-function declared fields against a field spec.
--- Each required field must be present and of the declared type; each present
--- field must match its declared type. Complements validate() (function hooks)
--- for scalar fields like `name` and `editorialMode`.
---
--- @param component table The module to check
--- @param fieldSpec table<string, { type: string, required: boolean }>
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validateFields(component, fieldSpec)
	if type(component) ~= 'table' then
		return false, { 'component is not a table (got ' .. type(component) .. ')' }
	end
	local errors = {}
	for field, decl in pairs(fieldSpec) do
		local value = component[field]
		if value == nil then
			if decl.required then
				table.insert(errors, 'missing required field: ' .. field)
			end
		elseif type(value) ~= decl.type then
			table.insert(
				errors,
				'field has wrong type: ' .. field .. ' (expected ' .. decl.type .. ', got ' .. type(value) .. ')'
			)
		end
	end
	return #errors == 0, errors
end

return p
