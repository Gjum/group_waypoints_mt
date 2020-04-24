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
		local player_id = pm_shim.get_player_id_for_name(plname)
		local defaults = group_waypoints.get_defaults_for_player(player_id) or {}
		local groupid = defaults.death_groupid or pm_shim.get_any_group_for_player(XXX_XXX)
		if not groupid then
			print("Cannot create death waypoint: Player " .. plname .. " has not configured a default group.")
			return
		end
		-- TODO delete any previous death waypoint of that player
		group_waypoints.create_waypoint {
			name = plname .. " Death",
			pos = player:get_pos(),
			groupid = groupid,
			creator = player_id
		}
	end
)

-- TODO check each player's waypoints' distance every few seconds or so, show/hide if in/out of range
