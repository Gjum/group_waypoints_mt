-- PlayerManager integrations

local exports = {}

function exports.get_group_name(groupid)
	return (pm.get_group_by_id(groupid) or {}).name
end

-- returns nil or list of {name, id, permission}
function exports.get_group_members(groupid)
	return pm.get_players_for_group(groupid)
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

return exports
