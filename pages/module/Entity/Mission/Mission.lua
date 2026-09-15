require('strict')

--- @module Entity/Mission

local format = require('Module:Entity/Format')
local Boolean = require('Module:Boolean')
local orderLines = require('Module:Entity/Orders/Lines').orderLines
local rewardLines = require('Module:Entity/Rewards/Lines').rewardLines

--- `mission_type` values whose display label is not the raw API string. The API
--- carries 30-odd types and CIG adds more with each patch, so labels are derived
--- from the raw value (see `typeLabel`) and only genuine exceptions are listed
--- here: the two Wikelo buckets are both barter collections to a reader, and the
--- lone `local` record is one mis-tagged Klescher mission whose sibling
--- (`RepairO2Kiosk` vs `PU_RepairO2Kiosk`) is tagged Maintenance.
--- @type table<string, string>
local TYPE_LABELS = {
	['Wikelo - Other Items'] = 'Collection',
	['Wikelo - Vehicles'] = 'Collection',
	['local'] = 'Maintenance',
}

local SCOPE = {
	['BountyHunter_BountyHuntersGuild'] = 'Bounty Hunter',
}

local function resolveReputationScope(scope)
	return SCOPE[scope] or scope
end

--- `mission_giver` is normally the better of the two faction names: it is the
--- specific contractor a reader can look up (MT Protection Services, BlacJac
--- Security, Miles Eckhart) where `faction.name` gives only the parent
--- corporation (microTech, ArcCorp, Eckhart Security). But on some records it is
--- an unresolved internal token instead, and those must not reach the page.
---
--- Matched on shape rather than by enumerating names, because the token set
--- grows with the data and the per-record `faction.name` is the right answer for
--- each: `MicroTechBountyDepartment` resolves to microTech on some records and
--- Hurston Dynamics on others. `XenoThreat` is deliberately NOT matched, being a
--- real faction name that happens to be unspaced.
--- @param giver string
--- @return boolean
local function isInternalToken(giver)
	return giver:find('_', 1, true) ~= nil
		or giver:find('~', 1, true) ~= nil
		or giver:find('BountyDepartment$') ~= nil
		or giver == 'N/A'
end

--- The faction to show and store: the mission giver, or that record's
--- `faction.name` when the giver is an internal token, or nil when neither is
--- usable (~100 records carry neither). One definition so the infobox row, the
--- stored `Faction` property and the short description can never disagree.
--- @param apiData table
--- @return string|nil
local function resolveFaction(apiData)
	local giver = apiData.mission_giver
	local factionName = apiData.faction and apiData.faction.name
	if type(giver) == 'string' and giver ~= '' and not isInternalToken(giver) then
		return giver
	end
	if type(factionName) == 'string' and factionName ~= '' then
		return factionName
	end
	return nil
end

--- The reader-facing name for a raw `mission_type`: an entry in TYPE_LABELS, or
--- the API string as-is. Derived rather than enumerated so a type CIG adds later
--- renders under its own name instead of erroring.
--- @param missionType string
--- @return string
local function typeLabel(missionType)
	return TYPE_LABELS[missionType] or missionType
end

--- The browse category for a type label, matching the names the retired
--- {{Contract}} template generated through {{Fixcaps}}: first letter upper, rest
--- lower, plus ' contracts'. So 'Bounty Hunter' routes to the existing
--- [[Category:Bounty hunter contracts]], not a near-miss duplicate.
--- @param label string
--- @return string
local function typeCategory(label)
	return mw.ustring.upper(mw.ustring.sub(label, 1, 1)) .. mw.ustring.lower(mw.ustring.sub(label, 2)) .. ' contracts'
end

local function linked(str)
	if type(str) == 'string' then
		return '[[' .. str .. ']]'
	end
	return str
end

local function fixTitle(title)
	title = string.gsub(title, '[%[%]]', '')
	title = string.gsub(title, '|', '-')
	return title
end

local p = {}

--- Canonical kind name, exposed as Data.get(args).kind (non-empty and
--- unique, enforced by the Registry conformance test).
p.name = 'Mission'

--- @type string
p.parent = 'Entity/Base'

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'missions/%s',
			responseDataPath = 'data',
		},
	}
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.mission_type ~= nil
end

--- @param ctx EntityHookContext
--- @return table|nil { name, category, categories }
function p.getTypeInfo(ctx)
	local missionType = ctx.apiData.mission_type
	if type(missionType) ~= 'string' or missionType == '' then
		return nil
	end
	local label = typeLabel(missionType)
	return {
		name = label,
		category = typeCategory(label),
		categories = { 'Contracts' },
	}
end

--- @param ctx EntityHookContext
--- @return table[]
function p.getSections(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local typeInfo = p.getTypeInfo(ctx)
	local faction = resolveFaction(apiData)

	local data = {
		category = 'Verified',
		type = typeInfo and typeInfo.name,
		cooldown = nil,
		shareable = 'Yes',
		available = 'Available',
		pickup = 'Contract Manager',
		payout = {
			uec = nil,
			scrip = {
				-- Overwritten by whichever scrip the contract actually awards;
				-- MG Scrip is the default only because it is the common case.
				name = 'MG Scrip',
				amount = 0,
			},
		},
		requirements = {
			fee = nil,
			missions = {},
		},
		reputation = {
			scope = nil,
			gain = nil,
			min = nil,
			max = nil,
		},
		location = {
			systems = {},
		},
		reward = {
			items = {},
			blueprints = {},
		},
	}

	if apiData.lifetime and apiData.lifetime.label then
		data.cooldown = apiData.lifetime.label
	end
	if args['available'] or apiData.not_for_release then
		if args['available'] then
			local x = args['available']:lower()
			data.available = (x == 'false' or x == 'no') and 'Unavailable' or 'Available'
		else
			data.available = 'Unavailable'
		end
	end
	if apiData.illegal then
		data.category = 'Unverified'
	end
	if apiData.shareable ~= nil and not apiData.shareable then
		data.shareable = 'No'
	end
	if args['pickup'] then
		data.pickup = args['pickup']
	elseif apiData.mission_giver == 'Wikelo' then
		data.pickup = 'Wikelo Emporium'
	end
	if apiData.cost then
		data.requirements.fee = apiData.cost
	end
	if apiData.prerequisite_groups and #apiData.prerequisite_groups > 0 then
		for _, group in ipairs(apiData.prerequisite_groups) do
			if group.missions and #group.missions > 0 then
				for _, mission in ipairs(group.missions) do
					if mission.variant_count then
						table.insert(
							data.requirements.missions,
							linked(fixTitle(mission.title)) .. ' x' .. tostring(mission.variant_count)
						)
					else
						table.insert(data.requirements.missions, linked(fixTitle(mission.title)))
					end
				end
			end
		end
	end

	data.payout.uec = args['payout'] or apiData.reward_min or data.payout.uec

	if apiData.reward_items and #apiData.reward_items > 0 then
		for _, reward in ipairs(apiData.reward_items) do
			if reward.name == 'MG Scrip' or reward.name == 'Council Scrip' then
				data.payout.scrip.name = reward.name
				data.payout.scrip.amount = data.payout.scrip.amount + reward.amount
			end
		end
	end

	data.reputation.min = apiData.min_standing and apiData.min_standing.name
		or (apiData.reputation_prerequisite and apiData.reputation_prerequisite.min_standing.name)
	data.reputation.max = apiData.max_standing and apiData.max_standing.name
		or (apiData.reputation_prerequisite and apiData.reputation_prerequisite.max_standing.name)
	data.reputation.scope = apiData.reputation_gained
		and #apiData.reputation_gained > 0
		and resolveReputationScope(apiData.reputation_gained[1].scope)
	data.reputation.gain = apiData.reputation_amount

	-- Always an array in the current corpus, but defaulted so the hook tolerates a
	-- partial record (the API omitting the key, or a caller passing one field).
	data.location.systems = apiData.star_systems or {}

	local general = {
		key = 'general',
		items = {
			{ label = 'Faction', content = linked(faction) },
			{ label = 'Category', content = data.category },
			{ label = 'Type', content = data.type },
			{ label = 'Contract Pickup', content = linked(data.pickup) },
			{ label = 'Shareable', content = Boolean.render(data.shareable) },
			{ label = 'Availability', content = data.available },
			{ label = 'Cooldown', content = data.cooldown },
		},
	}

	local sections = { general }

	if data.payout.uec or data.payout.scrip.amount > 0 then
		table.insert(sections, {
			key = 'payout',
			label = 'Payout',
			collapsible = true,
			items = {
				{ label = 'aUEC', content = format.formatNum(data.payout.uec) },
				{
					label = data.payout.scrip.name,
					content = data.payout.scrip.amount > 0 and format.formatNum(data.payout.scrip.amount),
				},
			},
		})
	end

	if data.reputation.min or data.reputation.max or data.reputation.scope or data.reputation.gain then
		table.insert(sections, {
			key = 'reputation',
			label = 'Reputation',
			collapsible = true,
			items = {
				{ label = 'Min', content = data.reputation.min },
				{ label = 'Max', content = data.reputation.max },
				{ label = 'Scope', content = data.reputation.scope },
				{ label = 'Gain', content = format.formatNum(data.reputation.gain) },
			},
		})
	end

	table.insert(sections, {
		key = 'requirements',
		label = 'Requirements',
		collapsible = true,
		items = {
			{ label = 'Fee', content = data.requirements.fee and format.formatNum(data.requirements.fee) .. ' aUEC' },
			{
				label = 'Contracts',
				content = #data.requirements.missions > 0 and table.concat(data.requirements.missions, ',<br/>'),
			},
		},
	})

	local location = {
		key = 'location',
		label = 'Location',
		collapsible = true,
		items = {},
	}

	if #data.location.systems > 0 then
		local systems = {}
		for _, system in ipairs(data.location.systems) do
			table.insert(systems, linked(system .. ' system'))
		end
		table.insert(location.items, { label = 'Systems', content = format.joinAnd(systems) })
	end

	if #location.items > 0 then
		table.insert(sections, location)
	end

	return sections
end

--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local typeInfo = p.getTypeInfo(ctx)
	local faction = resolveFaction(apiData)
	local scrip
	local available = true

	if args['available'] or apiData.not_for_release then
		if args['available'] then
			local x = args['available']:lower()
			if x == 'false' or x == 'no' then
				available = false
			else
				available = true
			end
		else
			available = false
		end
	end
	if apiData.reward_items and #apiData.reward_items > 0 then
		for _, reward in ipairs(apiData.reward_items) do
			if reward.name == 'MG Scrip' or reward.name == 'Council Scrip' then
				scrip = (scrip or 0) + reward.amount
			end
		end
	end

	local orders = orderLines(apiData.hauling_orders)
	local rewards = rewardLines(apiData.reward_groups, apiData.blueprints)

	return {
		legality = apiData.illegal and 'unverified' or 'verified',
		type = typeInfo and typeInfo.name,
		faction = faction,
		systems = apiData.star_systems,
		uec = args['payout'] or apiData.reward_min or nil,
		scrip = scrip,
		reputation_min = apiData.min_standing and apiData.min_standing.name
			or (apiData.reputation_prerequisite and apiData.reputation_prerequisite.min_standing.name)
			or 'None',
		reputation_max = apiData.max_standing and apiData.max_standing.name
			or (apiData.reputation_prerequisite and apiData.reputation_prerequisite.max_standing.name)
			or 'None',
		available = available,
		orders = #orders > 0 and orders or nil,
		rewards = #rewards > 0 and rewards or nil,
	}
end

--- "<Faction> <type> contract" e.g. "Headhunter mercenary contract", falling
--- back to "<Type> contract" for the ~100 records in the corpus that carry
--- neither a faction nor a mission giver, and to nil when even the type is
--- missing, which leaves the page's own SHORTDESC in place.
---
--- @param ctx EntityHookContext
--- @return string|nil
function p.getShortDescription(ctx)
	local apiData, typeInfo = ctx.apiData, ctx.typeInfo
	local faction = resolveFaction(apiData)
	local typeName = typeInfo and typeInfo.name

	if not typeName then
		return nil
	end
	if type(faction) ~= 'string' or faction == '' then
		return string.format('%s contract', (typeName:gsub('^%l', string.upper)))
	end

	return string.format('%s %s contract', faction:lower():gsub('^%l', string.upper), typeName:lower())
end

--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getExternalSiteItems(ctx)
	return {}
end

--- SCMDB as a footer action button, the same shape as the star systems'
--- Starmap button.
---
--- SCMDB keys its catalogue by the game's own contract GUID, which is the
--- value the API returns as `uuid`, so the page's uuid addresses the contract
--- there with no mapping table: `?g=` resolves against a contract id or one of
--- its contractDefinitionIds and the site then canonicalises the URL itself.
--- Its `?m=` form is a hash of the internal debug name, so it is not linkable
--- -- a rename breaks it silently and two contracts sharing a debug name
--- collide onto one URL.
---
--- Offered for every record with a uuid rather than gated on whether SCMDB
--- holds it. Its catalogue covers the contractor-given career contracts and
--- not the `PU_*` families, so a good fraction of ours are absent, but an id
--- it does not hold opens its mission browser rather than an error page.
---
--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	local uuid = ctx.args.uuid or ctx.apiData.uuid
	if type(uuid) ~= 'string' or uuid == '' then
		return {}
	end
	return {
		{
			label = 'SCMDB',
			url = 'https://scmdb.net/?g=' .. uuid,
			class = 't-button--branded t-button--scmdb',
		},
	}
end

return p
