if not notifier then
	return
end

local mod_creator = ":block_alert"
local alert_kind = "block_alert"

local original_send_player_alert = notifier.send_player_alert
notifier.send_player_alert = function(plname, event_type, node_pos, notifier_name, groupid)
	local result = original_send_player_alert(plname, event_type, node_pos, notifier_name, groupid)

	local existing_wp = nil
	local group_wps = group_waypoints.get_waypoints_in_group(groupid) or {}
	for wpid, wp in pairs(group_wps) do
		if wp.name == plname and wp.kind == alert_kind then
			if not existing_wp then
				existing_wp = wp
			else
				-- more than one player notification waypoints exist
				group_waypoints.delete_waypoint(mod_creator, wpid)
			end
		end
	end

	if existing_wp then
		group_waypoints.set_waypoint_pos(mod_creator, existing_wp.id, node_pos)
	else
		group_waypoints.create_waypoint {
			name = plname,
			pos = node_pos,
			kind = alert_kind,
			groupid = groupid,
			creator = mod_creator
		}
	end

	return result
end
