-- Registers event listeners to minetest.

local pm_shim = (...).pm_shim
local hud = (...).hud

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
		local groupid = defaults.death_groupid or pm_shim.get_any_group_for_player(plname)
		if not groupid then
			print("Cannot create death waypoint: Player " .. plname .. " has not configured a default group.")
			return
		end
		-- TODO delete any previous death waypoint of that player
		group_waypoints.create_waypoint {
			name = plname .. " Death",
			pos = player:get_pos(),
			kind = "death",
			groupid = groupid,
			creator = plname
		}
	end
)

-- TODO check each player's waypoints' distance every few seconds or so, show/hide if in/out of range
