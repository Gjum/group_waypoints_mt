group_waypoints = {} -- modules add functions to this table

--=== setup ===--

local util = loadfile(minetest.get_modpath("group_waypoints") .. "/util.lua")()

local waypoints = loadfile(minetest.get_modpath("group_waypoints") .. "/waypoints.lua")(util)
group_waypoints.get_waypoint_by_id = waypoints.get_waypoint_by_id
group_waypoints.get_waypoints_in_group = waypoints.get_waypoints_in_group
group_waypoints.create_waypoint = waypoints.create_waypoint
group_waypoints.delete_waypoint = waypoints.delete_waypoint
group_waypoints.set_waypoint_name = waypoints.set_waypoint_name
group_waypoints.set_waypoint_pos = waypoints.set_waypoint_pos
group_waypoints.set_waypoint_color = waypoints.set_waypoint_color
group_waypoints.on_waypoint_created = waypoints.on_waypoint_created
group_waypoints.on_waypoint_updated = waypoints.on_waypoint_updated
group_waypoints.on_waypoint_deleted = waypoints.on_waypoint_deleted
group_waypoints.allow_waypoint_created = waypoints.allow_waypoint_created
group_waypoints.allow_waypoint_updated = waypoints.allow_waypoint_updated
group_waypoints.allow_waypoint_deleted = waypoints.allow_waypoint_deleted

local settings = loadfile(minetest.get_modpath("group_waypoints") .. "/settings.lua")(util)
group_waypoints.get_defaults_for_player = settings.get_defaults_for_player
group_waypoints.set_defaults_for_player = settings.set_defaults_for_player
group_waypoints.get_group_visible_for_player = settings.get_group_visible_for_player
group_waypoints.set_group_visible_for_player = settings.set_group_visible_for_player
group_waypoints.get_group_range_for_player = settings.get_group_range_for_player
group_waypoints.set_group_range_for_player = settings.set_group_range_for_player
group_waypoints.get_group_color_for_player = settings.get_group_color_for_player
group_waypoints.set_group_color_for_player = settings.set_group_color_for_player
group_waypoints.get_waypoint_visible_for_player = settings.get_waypoint_visible_for_player
group_waypoints.set_waypoint_visible_for_player = settings.set_waypoint_visible_for_player
group_waypoints.on_player_defaults_updated = settings.on_player_defaults_updated
group_waypoints.on_group_setting_updated = settings.on_group_setting_updated
group_waypoints.on_waypoint_setting_updated = settings.on_waypoint_setting_updated

local hud = loadfile(minetest.get_modpath("group_waypoints") .. "/hud.lua")(util)
group_waypoints.allow_player_see_waypoint = hud.allow_player_see_waypoint

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
		local groupid = defaults.death_groupid or util.get_any_group_for_player(plname)
		if not groupid then
			print("Cannot create death waypoint: Player " .. plname .. " has not configured a default group.")
			return
		end
		-- TODO delete any previous death waypoint of that player
		group_waypoints.create_waypoint {
			name = plname .. " Death",
			pos = player:get_pos(),
			groupid = groupid,
			creator = plname
		}
	end
)

-- TODO check each player's waypoints' distance every few seconds or so, show/hide if in/out of range

--=== integrations ===--

group_waypoints.allow_waypoint_created(
	function(plname, waypoint)
		return util.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_updated(
	function(plname, waypoint)
		return plname == waypoint.plname and util.player_can_see_group(plname, waypoint.groupid) or
			util.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_deleted(
	function(plname, waypoint)
		return plname == waypoint.plname and util.player_can_see_group(plname, waypoint.groupid) or
			util.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_player_see_waypoint(
	function(plname, waypoint)
		return util.player_can_see_group(plname, waypoint.groupid)
	end
)

-- TODO on player role change: re-check all waypoints in that group for that player

-- TODO on group deletion: delete all waypoints in it; settings: all_group_overrides[groupid] = nil

-- TODO jukealert: update waypoint for player's last seen location, in notifier's reinforcement group
