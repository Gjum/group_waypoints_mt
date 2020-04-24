-- This module provides per-player settings for groups and individual waypoints.

-- TODO: after each set_*, clean up configs where all entries are null

local utils = (...).utils

local exports = {}

--=== events ===--

local player_defaults_updated_handlers = {}
function exports.on_player_defaults_updated(handler)
	player_defaults_updated_handlers[#player_defaults_updated_handlers + 1] = handler
end

local waypoint_updated_handlers = {}
function exports.on_waypoint_setting_updated(handler)
	waypoint_updated_handlers[#waypoint_updated_handlers + 1] = handler
end

local group_updated_handlers = {}
function exports.on_group_setting_updated(handler)
	group_updated_handlers[#group_updated_handlers + 1] = handler
end

local function emit_group_updated_event(player_id, groupid, config)
	utils.emit_event(group_updated_handlers, {player_id = player_id, groupid = groupid, config = config})
end

--=== state ===--

local all_group_overrides = {} -- groupid -> player_id -> {visible, range, color}
local all_wp_player_overrides = {} -- wpid -> player_id -> {visible}
local all_player_defaults = {} -- player_id -> {groupid}

function exports.load_group_overrides(group_overrides)
	local num_loaded = 0
	for _, group_override in pairs(group_overrides) do
		-- XXX load_group_overrides
		-- num_loaded = num_loaded + 1
	end
	return num_loaded
end

--- waypoint_overrides: list of {waypoint_id, player_id, visible}
function exports.load_waypoint_overrides(waypoint_overrides)
	local num_loaded = 0
	for _, wp_override in pairs(waypoint_overrides) do
		local wpid = wp_override.waypoint_id
		local player_id = wp_override.player_id
		local of_wp = all_wp_player_overrides[wpid] or {}
		of_wp[player_id] = {
			visible = wp_override.visible
		}
		all_wp_player_overrides[wpid] = of_wp
		num_loaded = num_loaded + 1
	end
	return num_loaded
end

function exports.load_player_defaults(player_defaults)
	local num_loaded = 0
	all_player_defaults = player_defaults
	return num_loaded
end

-- same as table_of_tables[key_first][key_second] but with nil handling
local function get_or_nil_deep2(table_of_tables, key_first, key_second)
	local table = table_of_tables[key_first]
	if not table then
		return nil
	end
	local subtable = table[key_second]
	if not subtable then
		return nil
	end
	return subtable
end

-- same as table_of_tables[key_first][key_second] but creates empty tables on the way when encountering nil entries
-- so you can always get_or_create_deep2(table_of_tables, key_first, key_second).some_key = some_value
local function get_or_create_deep2(table_of_tables, key_first, key_second)
	local table = table_of_tables[key_first]
	if not table then
		table = {}
		table_of_tables[key_first] = table
	end
	local entry = table[key_second]
	if not entry then
		entry = {}
		table[key_second] = entry
	end
	return entry
end

--=== actions ===--

function exports.get_defaults_for_player(player_id)
	return all_player_defaults[player_id]
end

function exports.set_defaults_for_player(player_id, defaults)
	all_player_defaults[player_id] = defaults
	utils.emit_event(player_defaults_updated_handlers, {player_id = player_id, defaults = defaults})
end

function exports.get_group_visible_for_player(player_id, groupid)
	local visible = (get_or_nil_deep2(all_group_overrides, groupid, player_id) or {}).visible
	return visible == nil or visible
end

-- If [visibility] is nil, rendering uses the player's visibility setting (dynamic).
function exports.set_group_visible_for_player(player_id, groupid, visible)
	local config = get_or_create_deep2(all_group_overrides, groupid, player_id)
	config.visible = visible
	emit_group_updated_event(player_id, groupid, config)
end

-- may return nil
function exports.get_group_range_for_player(player_id, groupid)
	return (get_or_nil_deep2(all_group_overrides, groupid, player_id) or {}).range
end

-- If [range] is nil, rendering uses the player's range setting (dynamic).
function exports.set_group_range_for_player(player_id, groupid, range)
	local config = get_or_create_deep2(all_group_overrides, groupid, player_id)
	config.range = range
	emit_group_updated_event(player_id, groupid, config)
end

-- may return nil
function exports.get_group_color_for_player(player_id, groupid)
	return (get_or_nil_deep2(all_group_overrides, groupid, player_id) or {}).color
end

-- If [color] is nil, rendering uses the player's color setting (dynamic).
function exports.set_group_color_for_player(player_id, groupid, color)
	local config = get_or_create_deep2(all_group_overrides, groupid, player_id)
	config.color = color
	emit_group_updated_event(player_id, groupid, config)
end

function exports.get_waypoint_visible_for_player(player_id, wpid)
	local visible = (get_or_nil_deep2(all_wp_player_overrides, wpid, player_id) or {}).visible
	return visible == nil or visible
end

-- If [visible] is nil, rendering uses the group's visibility setting (dynamic).
function exports.set_waypoint_visible_for_player(player_id, wpid, visible)
	local config = get_or_create_deep2(all_wp_player_overrides, wpid, player_id)
	config.visible = visible
	utils.emit_event(waypoint_updated_handlers, {player_id = player_id, wpid = wpid, config = config})
end

--=== event handlers ===--

group_waypoints.on_waypoint_deleted(
	function(wpid)
		all_wp_player_overrides[wpid] = nil
	end
)

return exports
