-- restrict waypoint actions via PlayerManager

local pmutils = (...).pmutils

group_waypoints.allow_waypoint_created(
	function(plname, waypoint)
		return pmutils.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_updated(
	function(plname, waypoint)
		return plname == waypoint.plname and pmutils.player_can_see_group(plname, waypoint.groupid) or
			pmutils.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_waypoint_deleted(
	function(plname, waypoint)
		return plname == waypoint.plname and pmutils.player_can_see_group(plname, waypoint.groupid) or
			pmutils.player_can_modify_group(plname, waypoint.groupid)
	end
)

group_waypoints.allow_player_see_waypoint(
	function(plname, waypoint)
		return pmutils.player_can_see_group(plname, waypoint.groupid)
	end
)
