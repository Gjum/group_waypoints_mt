-- This module provides CRUD operations on waypoint objects.
-- Events are emitted for C/U/D, see the on_waypoint_* functions.
-- C/U/D check if the player has access, via the corresponding allow_waypoint_* event.
-- They throw an error, so the caller needs to check access before calling.

local util = ...

--=== events ===--

local created_handlers = {}
local function on_waypoint_created(handler)
	created_handlers[#created_handlers + 1] = handler
end

local updated_handlers = {}
local function on_waypoint_updated(handler)
	updated_handlers[#updated_handlers + 1] = handler
end

local deleted_handlers = {}
local function on_waypoint_deleted(handler)
	deleted_handlers[#deleted_handlers + 1] = handler
end

local created_checks = {}
local function allow_waypoint_created(check)
	created_checks[#created_checks + 1] = check
end

local updated_checks = {}
local function allow_waypoint_updated(check)
	updated_checks[#updated_checks + 1] = check
end

local deleted_checks = {}
local function allow_waypoint_deleted(check)
	deleted_checks[#deleted_checks + 1] = check
end

--=== state and access ===--

local all_wps_by_id = {} -- wpid -> wp
local all_wps_by_groupid = {} -- groupid -> wpid -> wp

local function get_waypoint_by_id(wpid)
	return all_wps_by_id[wpid]
end

local function get_waypoints_in_group(groupid)
	local group_wps = all_wps_by_groupid[groupid]
	if not group_wps then
		group_wps = {}
		all_wps_by_groupid[groupid] = group_wps
	end
	return group_wps
end

local largest_id = 0
local function next_id()
	largest_id = largest_id + 1
	return largest_id
end

-- player pos -> block pos
local function pos_adjusted(pos)
	return {
		x = math.floor(pos.x),
		y = math.ceil(pos.y),
		z = math.floor(pos.z)
	}
end

local function coord_name(wp)
	return wp.pos.x .. " " .. wp.pos.y .. " " .. wp.pos.z
end

local function clean_wp(wp_in)
	local wp = {
		id = wp_in.id or next_id(),
		groupid = wp_in.groupid,
		creator = wp_in.creator,
		created_at = wp_in.created_at or os.time(),
		name = wp_in.name,
		pos = pos_adjusted(wp_in.pos),
		color = wp_in.color -- may be nil, in that case the player's group color is used
	}
	if not wp.name or wp.name == "" then
		wp.name = coord_name(wp)
	end
	return wp
end

local function load_waypoints(waypoints)
	for _, wp_in in pairs(waypoints) do
		if wp_in.id and largest_id < wp_in.id then
			largest_id = wp_in.id
		end
		local wp = clean_wp(wp_in)
		all_wps_by_id[wp.id] = wp
		local group_wps = get_waypoints_in_group(wp.groupid)
		group_wps[wp.id] = wp
	end
end

--=== creation ===--

local function create_waypoint(wp_in)
	if not wp_in.groupid then
		error("Tried creating waypoint without groupid")
	end
	if not wp_in.creator then
		error("Tried creating waypoint without creator")
	end

	wp_in.id = next_id()
	local wp = clean_wp(wp_in)

	local plname = wp.creator

	if not util.emit_allowed_check(created_checks, plname, wp) then
		error("Player '" .. plname .. "' cannot create waypoint in group" .. wp_in.group)
	end

	all_wps_by_id[wp.id] = wp
	local group_wps = get_waypoints_in_group(wp.groupid)
	group_wps[wp.id] = wp

	util.emit_event(created_handlers, wp)
	return wp
end

--=== delete/update ===--

local function delete_waypoint(plname, wpid)
	local wp = all_wps_by_id[wpid]
	if not wp then
		error("Cannot delete unknown waypoint id " .. wpid)
	end
	if not util.emit_allowed_check(deleted_checks, plname, wp) then
		error("Player '" .. plname .. "' is not allowed to delete waypoint id " .. wpid)
	end

	all_wps_by_id[wpid] = nil
	local group_wps = get_waypoints_in_group(wp.groupid)
	group_wps[wpid] = nil

	util.emit_event(deleted_handlers, wp)
end

local function set_waypoint_name(plname, wpid, name)
	local wp = get_waypoint_by_id(wpid)
	if not wp then
		error("Cannot update unknown waypoint id " .. wpid)
	end
	if not util.emit_allowed_check(updated_checks, plname, wp) then
		error("Player '" .. plname .. "' is not allowed to update waypoint id " .. wpid)
	end

	wp.name = name or coord_name(wp)
	util.emit_event(updated_handlers, wp)
	return wp
end

local function set_waypoint_pos(plname, wpid, pos)
	local wp = get_waypoint_by_id(wpid)
	if not wp then
		error("Cannot update unknown waypoint id " .. wpid)
	end
	if not util.emit_allowed_check(updated_checks, plname, wp) then
		error("Player '" .. plname .. "' is not allowed to update waypoint id " .. wpid)
	end

	wp.pos = pos
	util.emit_event(updated_handlers, wp)
	return wp
end

local function set_waypoint_color(plname, wpid, color)
	local wp = get_waypoint_by_id(wpid)
	if not wp then
		error("Cannot update unknown waypoint id " .. wpid)
	end
	if not util.emit_allowed_check(updated_checks, plname, wp) then
		error("Player '" .. plname .. "' is not allowed to update waypoint id " .. wpid)
	end

	wp.color = color
	util.emit_event(updated_handlers, wp)
	return wp
end

--=== exports ===--

group_waypoints.get_waypoint_by_id = get_waypoint_by_id
group_waypoints.get_waypoints_in_group = get_waypoints_in_group

group_waypoints.create_waypoint = create_waypoint
group_waypoints.delete_waypoint = delete_waypoint
group_waypoints.set_waypoint_name = set_waypoint_name
group_waypoints.set_waypoint_pos = set_waypoint_pos
group_waypoints.set_waypoint_color = set_waypoint_color

group_waypoints.on_waypoint_created = on_waypoint_created
group_waypoints.on_waypoint_updated = on_waypoint_updated
group_waypoints.on_waypoint_deleted = on_waypoint_deleted

group_waypoints.allow_waypoint_created = allow_waypoint_created
group_waypoints.allow_waypoint_updated = allow_waypoint_updated
group_waypoints.allow_waypoint_deleted = allow_waypoint_deleted

return {load_waypoints = load_waypoints}
