require('strict')

--- @module Entity/Contract
--- The Entity component contract as data + a checker. Defines, per role, which
--- lifecycle hooks exist and which are required, and validates a component
--- module against a role. Used by the registry conformance test so a mis-wired
--- kind or facet fails a unit test rather than silently no-opping on-wiki.
---
--- No runtime role in rendering — a contributor-facing guardrail. See
--- Module:Entity/doc for the prose contract reference.

local p = {}

--- Kind: a top-level entity with its own API endpoint, probed by matches().
--- `matches` + `getApiConfigs` identify it; the rest are optional chain-link
--- contributions a kind may also make as a chain root.
---
--- A kind's canonical scalar fields — `name` (exposed as Data.get().result.kind)
--- and the `editorialMode` opt-in — are absent from the spec below because
--- validate() type-checks every spec key as a function hook. They live in
--- p.KIND_FIELDS and are type-checked by validateFields() (run by the Registry
--- conformance test); `name`'s non-empty + uniqueness guarantee remains enforced
--- specifically by testAllKindsDeclareName in Module:Entity/Registry/testcases.
--- @type table<string, boolean>
p.KIND = {
	matches = true,
	getApiConfigs = true,
	resolveSubtype = false,
	enrich = false,
	getTypeInfo = false,
	getSections = false,
	getStructuredData = false,
	getShortDescription = false,
	getExternalSiteItems = false,
	getEditorialManifest = false,
	getSubtitle = false,
	getHeaderBadge = false,
	getCategories = false,
}

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

--- Chain link: a p.parent-linked contributor (Base, Item, subtypes). Every hook
--- optional — a link implements only what it adds.
--- @type table<string, boolean>
p.CHAIN_LINK = {
	getSections = false,
	getStructuredData = false,
	getShortDescription = false,
	getExternalSiteItems = false,
	getTypeInfo = false,
	getApiConfigs = false,
	getSubtitle = false,
	getHeaderBadge = false,
}

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
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validate(component, spec)
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
