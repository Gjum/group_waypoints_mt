-- PlayerManager integrations

local exports = {}

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
	local player_id = XXX
	assert(player_id)
	return player_id
end

-- returns nil or list of {name, id, permission}
function exports.get_player_groups(XXX_XXX)
	local pm_player = pm.get_player_by_name(plname)
	return pm.get_groups_for_player(pm_player.id)
end

function exports.get_player_rank_in_group(XXX_XXX, groupid)
	local pm_player = pm.get_player_by_name(XXX_XXX)
	return (pm.get_player_group(pm_player.id, groupid) or {}).permission
end

function exports.get_any_group_for_player(XXX_XXX)
	local defaults = group_waypoints.get_defaults_for_player(player_id) or {}
	if defaults.groupid then
		return defaults.groupid
	end
	return ((exports.get_player_groups(XXX_XXX) or {})[0] or {}).id
end

function exports.player_can_see_group(XXX_XXX, groupid)
	return nil ~= exports.get_player_rank_in_group(XXX_XXX, groupid)
end

function exports.player_can_modify_group(XXX_XXX, groupid)
	return "admin" == exports.get_player_rank_in_group(XXX_XXX, groupid)
end

return exports
