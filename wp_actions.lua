-- restrict waypoint actions via PlayerManager

local pm_shim = (...).pm_shim

group_waypoints.allow_waypoint_created(
	function(plname, waypoint)
		return pm_shim.player_can_see_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_updated(
	function(plname, waypoint)
		return plname == waypoint.plname and pm_shim.player_can_see_group(plname, waypoint.groupid) or
			pm_shim.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_deleted(
	function(plname, waypoint)
		return plname == waypoint.plname and pm_shim.player_can_see_group(plname, waypoint.groupid) or
			pm_shim.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_player_see_waypoint(
	function(plname, waypoint)
		return pm_shim.player_can_see_group(plname, waypoint.groupid)
	end
)
