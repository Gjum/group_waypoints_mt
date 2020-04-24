-- This module updates the player HUD to display the visible waypoints.

local utils = (...).utils
local pm_shim = (...).pm_shim

local exports = {}

--=== events ===--

local waypoint_visible_checks = {}
function exports.allow_player_see_waypoint(check)
	waypoint_visible_checks[#waypoint_visible_checks + 1] = check
end

--=== state ===--

local all_player_huds = {} -- plname -> wpid -> hud_id
local all_waypoint_huds = {} -- wpid -> plname -> hud_id

local function show_waypoint_to_player(plname, waypoint)
	local player = minetest.get_player_by_name(plname)
	if not player then
		return
	end

	local group_name = pm_shim.get_group_name(waypoint.groupid)
	local color = waypoint.color
		or group_waypoints.get_group_color_for_player(plname, waypoint.groupid)
		or 0xDDFFDD

	local hud_id =
		player:hud_add {
		hud_elem_type = "waypoint",
		alignment = {x = 0, y = 0},
		text = "m [" .. group_name .. "]",
		world_pos = waypoint.pos,
		name = waypoint.name,
		number = color
	}

	local player_huds = all_player_huds[plname]
	if not player_huds then
		player_huds = {}
		all_player_huds[plname] = player_huds
	end
	player_huds[waypoint.id] = hud_id

	local waypoint_huds = all_waypoint_huds[waypoint.id]
	if not waypoint_huds then
		waypoint_huds = {}
		all_waypoint_huds[waypoint.id] = waypoint_huds
	end
	waypoint_huds[plname] = hud_id

	return hud_id
end

local function hide_waypoint_from_player(plname, wpid)
	local hud_id = (all_player_huds[plname] or {})[wpid]
	if not hud_id then
		return -- player already does not see waypoint, nothing to do
	end

	local player = minetest.get_player_by_name(plname)
	if player then
		player:hud_remove(hud_id)
	end

	all_player_huds[plname][wpid] = nil
	all_waypoint_huds[wpid][plname] = nil
end

function exports.update_waypoint_for_player(plname, waypoint)
	local player = minetest.get_player_by_name(plname)
	if not player then
		return
	end

	local wpid = waypoint.id
	local groupid = waypoint.groupid

	local player_can_see_waypoint = utils.emit_allowed_check(waypoint_visible_checks, {plname=plname, waypoint=waypoint})
	if not player_can_see_waypoint then
		hide_waypoint_from_player(plname, wpid)
		return
	end

	local player_can_see_group = group_waypoints.get_group_visible_for_player(plname, groupid)
	if not player_can_see_group then
		hide_waypoint_from_player(plname, wpid)
		return
	end

	local player_disabled_waypoint = not group_waypoints.get_waypoint_visible_for_player(plname, wpid)
	if player_disabled_waypoint then
		hide_waypoint_from_player(plname, wpid)
		return
	end

	-- TODO check waypoint distance
	-- local ppos = player:get_pos()
	-- local group_range = group_waypoints.get_group_range_for_player(plname, groupid)
	-- if vector.distance(ppos, waypoint.pos) > group_range then
	-- 	hide_waypoint_from_player(plname, wpid)
	-- 	return
	-- end

	local existing_hud_id = (all_player_huds[plname] or {})[waypoint.id]
	if existing_hud_id then
		-- TODO update hud instead of remove+create
		player:hud_remove(existing_hud_id)
		show_waypoint_to_player(plname, waypoint)

		return
	end

	show_waypoint_to_player(plname, waypoint)
end

function exports.update_waypoint(waypoint)
	local wpid = waypoint.id

	-- TODO optimize: visibility check is called twice for all players that are currently seeing the waypoint

	-- remove from all players that were seeing it but may no longer see it
	for plname, hud_id in pairs(all_waypoint_huds[wpid] or {}) do
		if not utils.emit_allowed_check(waypoint_visible_checks, {plname=plname, waypoint=waypoint}) then
			hide_waypoint_from_player(plname, wpid)
		end
	end

	-- show to all players that may see it
	for _, pm_player in ipairs(pm_shim.get_group_members(waypoint.groupid) or {}) do
		exports.update_waypoint_for_player(pm_player.name, waypoint)
	end
end

-- show/hide all waypoints of that player
function exports.update_all_waypoints_for_player(plname)
	-- hide all waypoints that are now no longer visible
	for wpid, hud_id in pairs(all_player_huds[plname] or {}) do
		local waypoint = group_waypoints.get_waypoint_by_id(wpid)
		if waypoint then
			exports.update_waypoint_for_player(plname, waypoint)
		else -- waypoint was deleted
			hide_waypoint_from_player(plname, wpid)
		end
	end
	-- show all waypoints that are now visible
	for _, group in ipairs(pm_shim.get_player_groups(plname) or {}) do
		local group_wps = group_waypoints.get_waypoints_in_group(group.id) or {}
		for wpid, waypoint in pairs(group_wps) do
			exports.update_waypoint_for_player(plname, waypoint)
		end
	end
end

--=== event handlers ===--

group_waypoints.on_waypoint_created(
	function(waypoint)
		exports.update_waypoint(waypoint)
	end
)

group_waypoints.on_waypoint_updated(
	function(waypoint)
		exports.update_waypoint(waypoint)
	end
)

group_waypoints.on_waypoint_deleted(
	function(waypoint)
		local wpid = waypoint.id
		-- this could have been implemented using hide_waypoint_from_player, but this implementation is optimized
		local waypoint_hud_ids = all_waypoint_huds[wpid] or {}
		for plname, hud_id in pairs(waypoint_hud_ids) do
			local player = minetest.get_player_by_name(plname)
			if player then
				player:hud_remove(hud_id)
			end
			all_player_huds[plname][wpid] = nil
		end
		all_waypoint_huds[wpid] = nil
	end
)

group_waypoints.on_player_defaults_updated(
	function(event)
		-- local defaults = event.defaults
		-- TODO only update the waypoints/groups that are impacted
		exports.update_all_waypoints_for_player(event.plname)
	end
)

group_waypoints.on_group_setting_updated(
	function(event)
		local group_wps = group_waypoints.get_waypoints_in_group(event.groupid)
		for wpid, waypoint in pairs(group_wps or {}) do
			exports.update_waypoint_for_player(event.plname, waypoint)
		end
	end
)

group_waypoints.on_waypoint_setting_updated(
	function(event)
		local waypoint = group_waypoints.get_waypoint_by_id(event.wpid)
		exports.update_waypoint_for_player(event.plname, waypoint)
	end
)

local function update_waypoints_in_group_for_player(plname, groupid)
	local group_wps = group_waypoints.get_waypoints_in_group(groupid)
	for wpid, waypoint in pairs(group_wps or {}) do
		exports.update_waypoint_for_player(plname, waypoint)
	end
end

pm_shim.on_pm_player_added(
	function(event)
		update_waypoints_in_group_for_player(event.plname, event.groupid)
	end
)

pm_shim.on_pm_player_removed(
	function(event)
		update_waypoints_in_group_for_player(event.plname, event.groupid)
	end
)

return exports
