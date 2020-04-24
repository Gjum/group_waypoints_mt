-- restrict waypoint actions via PlayerManager

local pm_shim = (...).pm_shim

group_waypoints.allow_waypoint_created(
	function(event)
		return pm_shim.player_can_see_group(event.plname, event.waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_updated(
	function(event)
		if event.plname == event.waypoint.plname then
			return pm_shim.player_can_see_group(event.plname, event.waypoint.groupid)
		else
			return pm_shim.player_can_modify_group(event.plname, event.waypoint.groupid)
		end
	end
)

group_waypoints.allow_waypoint_deleted(
	function(event)
		if event.plname == event.waypoint.plname then
			return pm_shim.player_can_see_group(event.plname, event.waypoint.groupid)
		else
			return pm_shim.player_can_modify_group(event.plname, event.waypoint.groupid)
		end
	end
)

group_waypoints.allow_player_see_waypoint(
	function(event)
		return pm_shim.player_can_see_group(event.plname, event.waypoint.groupid)
	end
)
