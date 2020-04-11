-- This module provides CRUD operations on waypoint objects.
-- Events are emitted for C/U/D, see the on_waypoint_* functions.
-- C/U/D check if the player has access, via the corresponding allow_waypoint_* event.
-- They throw an error, so the caller needs to check access before calling.

local utils = (...).utils
local pmutils = (...).pmutils

local exports = {}

--=== events ===--

local created_handlers = {}
function exports.on_waypoint_created(handler)
	created_handlers[#created_handlers + 1] = handler
end

local updated_handlers = {}
function exports.on_waypoint_updated(handler)
	updated_handlers[#updated_handlers + 1] = handler
end

local deleted_handlers = {}
function exports.on_waypoint_deleted(handler)
	deleted_handlers[#deleted_handlers + 1] = handler
end

local created_checks = {}
function exports.allow_waypoint_created(check)
	created_checks[#created_checks + 1] = check
end

local updated_checks = {}
function exports.allow_waypoint_updated(check)
	updated_checks[#updated_checks + 1] = check
end

local deleted_checks = {}
function exports.allow_waypoint_deleted(check)
	deleted_checks[#deleted_checks + 1] = check
end

--=== state and access ===--

local all_wps_by_id = {} -- wpid -> wp
local all_wps_by_groupid = {} -- groupid -> wpid -> wp

local largest_id = 0
local function next_id(wp)
	largest_id = largest_id + 1
	return largest_id
end

-- player pos -> block pos
local function pos_adjusted(pos)
	return {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)
	}
end

local function clean_wp(wp_in)
	-- TODO ensure wp_in.groupid exists

	local wp = {
		id = wp_in.id,
		groupid = wp_in.groupid,
		creator = wp_in.creator,
		created_at = wp_in.created_at or os.time(),
		name = wp_in.name,
		pos = pos_adjusted(wp_in.pos),
		color = wp_in.color -- may be nil, in that case the player's group color is used
	}

	wp.id = wp.id or next_id(wp)

	if not wp.name or wp.name == "" then
		wp.name = utils.pos_to_str(wp.pos)
	end

	return wp
end

function exports.get_waypoint_by_id(wpid)
	return all_wps_by_id[wpid]
end

function exports.get_waypoints_in_group(groupid)
	local group_wps = all_wps_by_groupid[groupid]
	if not group_wps then
		group_wps = {}
		all_wps_by_groupid[groupid] = group_wps
	end
	return group_wps
end

function exports.get_waypoints_for_player(plname)
	local player_waypoints = {}
	for _, group in ipairs(pmutils.get_player_groups(plname) or {}) do
		local group_wps = group_waypoints.get_waypoints_in_group(group.id) or {}
		for wpid, waypoint in pairs(group_wps) do
			player_waypoints[wpid] = waypoint
		end
	end
	return player_waypoints
end

function exports.load_waypoints(waypoints)
	for _, wp_in in pairs(waypoints) do
		if wp_in.id and largest_id < wp_in.id then
			largest_id = wp_in.id
		end
		local wp = clean_wp(wp_in)
		all_wps_by_id[wp.id] = wp
		local group_wps = exports.get_waypoints_in_group(wp.groupid)
		group_wps[wp.id] = wp
	end
end

--=== creation ===--

function exports.create_waypoint(wp_in)
	if not wp_in.groupid then
		error("Tried creating waypoint without groupid")
	end
	if not wp_in.creator then
		error("Tried creating waypoint without creator")
	end

	wp_in.id = next_id(wp_in)
	local wp = clean_wp(wp_in)

	local plname = wp.creator

	if not utils.emit_allowed_check(created_checks, plname, wp) then
		error("Player '" .. plname .. "' cannot create waypoint in group " .. dump(wp.groupid))
	end

	all_wps_by_id[wp.id] = wp
	local group_wps = exports.get_waypoints_in_group(wp.groupid)
	group_wps[wp.id] = wp

	utils.emit_event(created_handlers, wp)
	return wp
end

--=== delete/update ===--

function exports.can_player_delete_waypoint(plname, wp)
	return utils.emit_allowed_check(deleted_checks, plname, wp)
end

function exports.can_player_update_waypoint(plname, wp)
	return utils.emit_allowed_check(updated_checks, plname, wp)
end

--- returns true if successful, false if player is not allowed to delete the waypoint
function exports.delete_waypoint(plname, wpid)
	local wp = all_wps_by_id[wpid]
	if not wp then
		minetest.log("Player " .. plname .. " cannot delete unknown waypoint id " .. wpid)
		return false
	end
	if not exports.can_player_delete_waypoint(plname, wp) then
		minetest.log("Player '" .. plname .. "' is not allowed to delete waypoint id " .. wpid)
		return false
	end

	all_wps_by_id[wpid] = nil
	local group_wps = exports.get_waypoints_in_group(wp.groupid)
	group_wps[wpid] = nil

	utils.emit_event(deleted_handlers, wp)
	return true
end

--- returns the waypoint if successful, nil if the player has no permission
function exports.set_waypoint_name(plname, wpid, name)
	local wp = exports.get_waypoint_by_id(wpid)
	if not wp then
		minetest.log("Player " .. plname .. " cannot update unknown waypoint id " .. dump2(wpid))
		return nil
	end
	if not exports.can_player_update_waypoint(plname, wp) then
		minetest.log(("Player '%s' is not allowed to rename waypoint id %s to %s"):format(
			plname, wpid, dump2(name)))
		return nil
	end

	if name == nil or name == "" then
		name = utils.pos_to_str(wp.pos)
	end

	wp.name = name
	utils.emit_event(updated_handlers, wp)
	return wp
end

--- returns the waypoint if successful, nil if the player has no permission
function exports.set_waypoint_pos(plname, wpid, pos)
	local wp = exports.get_waypoint_by_id(wpid)
	if not wp then
		minetest.log("Player " .. plname .. " cannot update unknown waypoint id " .. dump2(wpid))
		return nil
	end
	if not exports.can_player_update_waypoint(plname, wp) then
		minetest.log(("Player '%s' is not allowed to move waypoint id %s to %s"):format(
			plname, wpid, utils.pos_to_str(pos)))
		return nil
	end

	wp.pos = pos
	utils.emit_event(updated_handlers, wp)
	return wp
end

--- returns the waypoint if successful, nil if the player has no permission
function exports.set_waypoint_color(plname, wpid, color)
	local wp = exports.get_waypoint_by_id(wpid)
	if not wp then
		minetest.log("Player " .. plname .. " cannot update unknown waypoint id " .. dump2(wpid))
		return nil
	end
	if not exports.can_player_update_waypoint(plname, wp) then
		minetest.log(("Player '%s' is not allowed to set waypoint id %s color to %s"):format(
			plname, wpid, dump2(color)))
		return nil
	end

	wp.color = color
	utils.emit_event(updated_handlers, wp)
	return wp
end

return exports
