group_waypoints = {} -- modules add functions to this table

--=== utils ===--

local function emit_allowed_check(checks, plname, event)
	for _, check in pairs(checks) do
		if not check(plname, event) then
			return false
		end
	end
	return true
end

local function emit_event(handlers, event)
	for _, handler in pairs(handlers) do
		handler(event)
	end
end

--=== integrations pt. 1/2 ===--

local function get_group_name(groupid)
	return (pm.get_group_by_id(groupid) or {}).name
end

-- returns nil or list of {name, id, permission}
local function get_group_members(groupid)
	return pm.get_players_for_group(groupid)
end

-- returns nil or list of {name, id, permission}
local function get_player_groups(plname)
	local pm_player = pm.get_player_by_name(plname)
	return pm.get_groups_for_player(pm_player.id)
end

local function get_player_rank_in_group(plname, groupid)
	local pm_player = pm.get_player_by_name(plname)
	return (pm.get_player_group(pm_player.id, groupid) or {}).permission
end

local function get_any_group_for_player(plname)
	local defaults = group_waypoints.get_defaults_for_player(plname) or {}
	if defaults.groupid then
		return defaults.groupid
	end
	return ((get_player_groups(plname) or {})[0] or {}).id
end

local function player_can_see_group(plname, groupid)
	return nil ~= get_player_rank_in_group(plname, groupid)
end

local function player_can_modify_group(plname, groupid)
	return "admin" == get_player_rank_in_group(plname, groupid)
end

--=== setup ===--

local util = {
	emit_allowed_check = emit_allowed_check,
	emit_event = emit_event,
	get_group_members = get_group_members,
	get_group_name = get_group_name,
	get_player_groups = get_player_groups
}

local waypoints = loadfile(minetest.get_modpath("group_waypoints") .. "/waypoints.lua")(util)
local settings = loadfile(minetest.get_modpath("group_waypoints") .. "/settings.lua")(util)
local hud = loadfile(minetest.get_modpath("group_waypoints") .. "/hud.lua")(util)

--=== startup ===--

-- XXX load waypoints and settings from db

--=== event handlers ===--

minetest.register_on_joinplayer(
	function(player)
		local plname = player:get_player_name()
		hud.update_all_waypoints_for_player(plname)
	end
)

minetest.register_on_dieplayer(
	function(player, reason)
		local plname = player:get_player_name()
		local defaults = group_waypoints.get_defaults_for_player(plname) or {}
		local groupid = defaults.death_groupid or get_any_group_for_player(plname)
		if not groupid then
			print("Cannot create death waypoint: Player " .. plname .. " has not configured a default group.")
			return
		end
		local death_wp =
			group_waypoints.create_waypoint {
			name = plname .. " Death",
			pos = player:get_pos(),
			groupid = groupid,
			creator = plname
		}
		-- TODO delete any previous death waypoint of that player
	end
)

-- TODO check each player's waypoints' distance every few seconds or so, show/hide if in/out of range

--=== integrations pt. 2/2 ===--

group_waypoints.allow_waypoint_created(
	function(plname, waypoint)
		return player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_updated(
	function(plname, waypoint)
		return plname == waypoint.plname and player_can_see_group(plname, waypoint.groupid) or
			player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_deleted(
	function(plname, waypoint)
		return plname == waypoint.plname and player_can_see_group(plname, waypoint.groupid) or
			player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_player_see_waypoint(
	function(plname, waypoint)
		return player_can_see_group(plname, waypoint.groupid)
	end
)

-- TODO on player role change: re-check all waypoints in that group for that player: hide_group_waypoints(plname, groupid)

-- TODO on group deletion: delete all waypoints in it; settings: all_group_overrides[groupid] = nil

-- TODO jukealert: update waypoint for player's last seen location, in notifier's reinforcement group
