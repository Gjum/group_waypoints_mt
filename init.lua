group_waypoints = {} -- modules add functions to this table

--=== setup ===--

local internal = {}

local modpath = minetest.get_modpath("group_waypoints")

internal.utils = loadfile(modpath .. "/utils.lua")()

internal.pmutils = loadfile(modpath .. "/pmutils.lua")()

internal.waypoints = loadfile(modpath .. "/waypoints.lua")(internal)
group_waypoints.get_waypoint_by_id = internal.waypoints.get_waypoint_by_id
group_waypoints.get_waypoints_in_group = internal.waypoints.get_waypoints_in_group
group_waypoints.get_waypoints_for_player = internal.waypoints.get_waypoints_for_player
group_waypoints.create_waypoint = internal.waypoints.create_waypoint
group_waypoints.delete_waypoint = internal.waypoints.delete_waypoint
group_waypoints.set_waypoint_name = internal.waypoints.set_waypoint_name
group_waypoints.set_waypoint_pos = internal.waypoints.set_waypoint_pos
group_waypoints.set_waypoint_color = internal.waypoints.set_waypoint_color
group_waypoints.on_waypoint_created = internal.waypoints.on_waypoint_created
group_waypoints.on_waypoint_updated = internal.waypoints.on_waypoint_updated
group_waypoints.on_waypoint_deleted = internal.waypoints.on_waypoint_deleted
group_waypoints.allow_waypoint_created = internal.waypoints.allow_waypoint_created
group_waypoints.allow_waypoint_updated = internal.waypoints.allow_waypoint_updated
group_waypoints.allow_waypoint_deleted = internal.waypoints.allow_waypoint_deleted

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

-- internal.db = loadfile(modpath .. "/db.lua")(internal)
-- XXX load waypoints and settings from db

internal.hud = loadfile(modpath .. "/hud.lua")(internal)
group_waypoints.allow_player_see_waypoint = internal.hud.allow_player_see_waypoint

internal.forms = loadfile(modpath .. "/forms.lua")(internal)
group_waypoints.show_wplist_formspec = internal.forms.show_wplist_formspec

loadfile(modpath .. "/commands.lua")(internal)

loadfile(modpath .. "/mt_events.lua")(internal)

--=== integrations ===--

loadfile(modpath .. "/wp_actions.lua")(internal)

-- TODO on player role change: re-check all waypoints in that group for that player

-- TODO on group deletion: delete all waypoints in it; settings: all_group_overrides[groupid] = nil

-- TODO jukealert: update waypoint for player's last seen location, in notifier's reinforcement group
