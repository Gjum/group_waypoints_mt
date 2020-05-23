group_waypoints = {} -- modules add functions to this table

--=== setup ===--

local internal = {}

local modpath = minetest.get_modpath("group_waypoints")

internal.utils = loadfile(modpath .. "/utils.lua")()

internal.pm_shim = loadfile(modpath .. "/pm_shim.lua")(internal)

internal.waypoints = loadfile(modpath .. "/waypoints.lua")(internal)
group_waypoints.get_waypoint_by_id = internal.waypoints.get_waypoint_by_id
group_waypoints.get_waypoints_in_group = internal.waypoints.get_waypoints_in_group
group_waypoints.get_waypoints_for_player = internal.waypoints.get_waypoints_for_player
group_waypoints.create_waypoint = internal.waypoints.create_waypoint
group_waypoints.delete_waypoint = internal.waypoints.delete_waypoint
group_waypoints.set_waypoint_name = internal.waypoints.set_waypoint_name
group_waypoints.set_waypoint_pos = internal.waypoints.set_waypoint_pos
group_waypoints.set_waypoint_color = internal.waypoints.set_waypoint_color
group_waypoints.player_can_update_waypoint = internal.waypoints.player_can_update_waypoint
group_waypoints.player_can_delete_waypoint = internal.waypoints.player_can_delete_waypoint
group_waypoints.on_waypoint_created = internal.waypoints.on_waypoint_created
group_waypoints.on_waypoint_updated = internal.waypoints.on_waypoint_updated
group_waypoints.on_waypoint_deleted = internal.waypoints.on_waypoint_deleted

internal.settings = loadfile(modpath .. "/settings.lua")(internal)
group_waypoints.get_defaults_for_player = internal.settings.get_defaults_for_player
group_waypoints.set_defaults_for_player = internal.settings.set_defaults_for_player
group_waypoints.get_group_visible_for_player = internal.settings.get_group_visible_for_player
group_waypoints.set_group_visible_for_player = internal.settings.set_group_visible_for_player
group_waypoints.get_group_range_for_player = internal.settings.get_group_range_for_player
group_waypoints.set_group_range_for_player = internal.settings.set_group_range_for_player
group_waypoints.get_group_color_for_player = internal.settings.get_group_color_for_player
group_waypoints.set_group_color_for_player = internal.settings.set_group_color_for_player
group_waypoints.get_waypoint_visible_for_player = internal.settings.get_waypoint_visible_for_player
group_waypoints.set_waypoint_visible_for_player = internal.settings.set_waypoint_visible_for_player
group_waypoints.on_player_defaults_updated = internal.settings.on_player_defaults_updated
group_waypoints.on_group_setting_updated = internal.settings.on_group_setting_updated
group_waypoints.on_waypoint_setting_updated = internal.settings.on_waypoint_setting_updated

internal.insecure_env = minetest.request_insecure_environment() or
	error("group_waypoints needs to be a trusted mod. " ..
		"Add it to `secure.trusted_mods` in minetest.conf")

internal.db = loadfile(modpath .. "/db.lua")(internal)
local num_loaded_waypoints = internal.waypoints.load_waypoints(
	internal.db.load_all_waypoints())
minetest.log("[group_waypoints] Loaded " .. num_loaded_waypoints .. " waypoints from Postgres")

local num_loaded_wp_overrides = internal.settings.load_waypoint_overrides(
	internal.db.load_all_waypoint_player_overrides())
minetest.log("[group_waypoints] Loaded " .. num_loaded_wp_overrides .. " waypoint player overrides from Postgres")

internal.hud = loadfile(modpath .. "/hud.lua")(internal)
group_waypoints.player_can_see_waypoint = internal.hud.player_can_see_waypoint

internal.forms = loadfile(modpath .. "/forms.lua")(internal)
group_waypoints.show_wplist_formspec = internal.forms.show_wplist_formspec

loadfile(modpath .. "/commands.lua")(internal)

loadfile(modpath .. "/mt_events.lua")(internal)

--=== integrations ===--

loadfile(modpath .. "/block_alert_events.lua")(internal)
