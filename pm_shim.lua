-- PlayerManager integrations: accessors and events

local utils = (...).utils

local exports = {}

--=== accessors ===--

function exports.get_group_name(groupid)
	return (pm.get_group_by_id(groupid) or {}).name
end

function exports.get_group_id_by_name(group_name)
	return (pm.get_group_by_name(group_name) or {}).id
end

-- returns nil or list of {name, id, permission}
function exports.get_group_members(groupid)
	return pm.get_players_for_group(groupid)
end

-- throws error if player was not found
function exports.get_player_id_for_name(plname)
	local player = pm.get_player_by_name(plname)
	assert(player)
	return player.id
end

-- throws error if player was not found
function exports.get_player_name_for_id(player_id)
	local player = pm.get_player_by_id(player_id)
	assert(player)
	return player.name
end

-- returns nil or list of {name, id, permission}
function exports.get_player_groups(plname)
	local pm_player = pm.get_player_by_name(plname)
	return pm.get_groups_for_player(pm_player.id)
end

function exports.get_player_rank_in_group(plname, groupid)
	local pm_player = pm.get_player_by_name(plname)
	return (pm.get_player_group(pm_player.id, groupid) or {}).permission
end

function exports.get_any_group_for_player(plname)
	local defaults = group_waypoints.get_defaults_for_player(plname) or {}
	if defaults.groupid then
		return defaults.groupid
	end
	return ((exports.get_player_groups(plname) or {})[0] or {}).id
end

function exports.player_can_see_group(plname, groupid)
	return nil ~= exports.get_player_rank_in_group(plname, groupid)
end

function exports.player_can_modify_group(plname, groupid)
	return "admin" == exports.get_player_rank_in_group(plname, groupid)
end

--=== events ===--

local player_added_handlers = {}
function exports.on_pm_player_added(handler)
	player_added_handlers[#player_added_handlers + 1] = handler
end

local original_register_player_group_permission = pm.register_player_group_permission
pm.register_player_group_permission = function(player_id, ctgroup_id, permission)
	local result = original_register_player_group_permission(player_id, ctgroup_id, permission)
	local plname = exports.get_player_name_for_id(player_id)
	utils.emit_event(player_added_handlers, {
		plname=plname, player_id=player_id, groupid=ctgroup_id})
	return result
end

local player_removed_handlers = {}
function exports.on_pm_player_removed(handler)
	player_removed_handlers[#player_removed_handlers + 1] = handler
end

local original_delete_player_group = pm.delete_player_group
pm.delete_player_group = function(player_id, ctgroup_id)
	local result = original_delete_player_group(player_id, ctgroup_id)
	local plname = exports.get_player_name_for_id(player_id)
	utils.emit_event(player_removed_handlers, {
		plname=plname, player_id=player_id, groupid=ctgroup_id})
	return result
end

local group_deleted_handlers = {}
function exports.on_pm_group_deleted(handler)
	group_deleted_handlers[#group_deleted_handlers + 1] = handler
end

local original_delete_group = pm.delete_group
pm.delete_group = function(ctgroup_id)
	local result = original_delete_group(ctgroup_id)
	utils.emit_event(group_deleted_handlers, ctgroup_id)
	return result
end

return exports
