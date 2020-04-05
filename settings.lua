-- This module provides per-player settings for groups and individual waypoints.

-- TODO: after each set_*, clean up configs where all entries are null

local util = ...

--=== events ===--

local player_defaults_updated_handlers = {}
local function on_player_defaults_updated(handler)
	player_defaults_updated_handlers[#player_defaults_updated_handlers + 1] = handler
end

local waypoint_updated_handlers = {}
local function on_waypoint_setting_updated(handler)
	waypoint_updated_handlers[#waypoint_updated_handlers + 1] = handler
end

local group_updated_handlers = {}
local function on_group_setting_updated(handler)
	group_updated_handlers[#group_updated_handlers + 1] = handler
end

local function emit_group_updated_event(plname, groupid, config)
	util.emit_event(group_updated_handlers, {plname = plname, groupid = groupid, config = config})
end

--=== state ===--

local all_group_overrides = {} -- groupid -> plname -> {visible, range, color}
local all_wp_player_overrides = {} -- wpid -> plname -> {visible}
local all_player_defaults = {} -- plname -> {groupid}

local function load_group_overrides(group_overrides)
	for _, wp_in in pairs(group_overrides) do
		-- XXX load_group_overrides
	end
end

local function load_waypoint_overrides(group_overrides)
	for _, wp_in in pairs(group_overrides) do
		-- XXX load_waypoint_overrides
	end
end

local function load_player_defaults(player_defaults)
	all_player_defaults = player_defaults
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

local function get_defaults_for_player(plname)
	return all_player_defaults[plname]
end

local function set_defaults_for_player(plname, defaults)
	all_player_defaults[plname] = defaults
	util.emit_event(player_defaults_updated_handlers, {plname = plname, defaults = defaults})
end

local function get_group_visible_for_player(plname, groupid)
	local visible = (get_or_nil_deep2(all_group_overrides, groupid, plname) or {}).visible
	return visible == nil or visible
end

-- If [visibility] is nil, rendering uses the player's visibility setting (dynamic).
local function set_group_visible_for_player(plname, groupid, visible)
	local config = get_or_create_deep2(all_group_overrides, groupid, plname)
	config.visible = visible
	emit_group_updated_event(plname, groupid, config)
end

-- may return nil
local function get_group_range_for_player(plname, groupid)
	return (get_or_nil_deep2(all_group_overrides, groupid, plname) or {}).range
end

-- If [range] is nil, rendering uses the player's range setting (dynamic).
local function set_group_range_for_player(plname, groupid, range)
	local config = get_or_create_deep2(all_group_overrides, groupid, plname)
	config.range = range
	emit_group_updated_event(plname, groupid, config)
end

-- may return nil
local function get_group_color_for_player(plname, groupid)
	return (get_or_nil_deep2(all_group_overrides, groupid, plname) or {}).color
end

-- If [color] is nil, rendering uses the player's color setting (dynamic).
local function set_group_color_for_player(plname, groupid, color)
	local config = get_or_create_deep2(all_group_overrides, groupid, plname)
	config.color = color
	emit_group_updated_event(plname, groupid, config)
end

local function get_waypoint_visible_for_player(plname, wpid)
	local visible = (get_or_nil_deep2(all_wp_player_overrides, wpid, plname) or {}).visible
	return visible == nil or visible
end

-- If [visible] is nil, rendering uses the group's visibility setting (dynamic).
local function set_waypoint_visible_for_player(plname, wpid, visible)
	local config = get_or_create_deep2(all_wp_player_overrides, wpid, plname)
	config.visible = visible
	util.emit_event(waypoint_updated_handlers, {plname = plname, wpid = wpid, config = config})
end

--=== event handlers ===--

group_waypoints.on_waypoint_deleted(
	function(wpid)
		all_wp_player_overrides[wpid] = nil
	end
)

--=== exports ===--

group_waypoints.get_defaults_for_player = get_defaults_for_player
group_waypoints.set_defaults_for_player = set_defaults_for_player
group_waypoints.get_group_visible_for_player = get_group_visible_for_player
group_waypoints.set_group_visible_for_player = set_group_visible_for_player
group_waypoints.get_group_range_for_player = get_group_range_for_player
group_waypoints.set_group_range_for_player = set_group_range_for_player
group_waypoints.get_group_color_for_player = get_group_color_for_player
group_waypoints.set_group_color_for_player = set_group_color_for_player
group_waypoints.get_waypoint_visible_for_player = get_waypoint_visible_for_player
group_waypoints.set_waypoint_visible_for_player = set_waypoint_visible_for_player
group_waypoints.on_player_defaults_updated = on_player_defaults_updated
group_waypoints.on_group_setting_updated = on_group_setting_updated
group_waypoints.on_waypoint_setting_updated = on_waypoint_setting_updated

return {
	load_group_overrides = load_group_overrides,
	load_waypoint_overrides = load_waypoint_overrides,
	load_player_defaults = load_player_defaults
}
