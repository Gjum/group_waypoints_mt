-- tracks the last group that a player added a waypoint to
-- so it can be used as default for wpadd

local utils = (...).utils
local pmutils = (...).pmutils

local actions_table = {}
local actions_aliases = {}

-- comma-separated sorted list of available actions
local function actions_str()
	local actions = {}
	for action_name, action_spec in pairs(actions_table) do
		actions[#actions + 1] = action_name:lower()
	end
	for action_name, action_spec in pairs(actions_aliases) do
		actions[#actions + 1] = action_name:lower()
	end
	table.sort(actions, function(a, b) return a < b end)
	return table.concat(actions, ", ")
end

local function cmd_help(plname, action_name)
	if not action_name then
		return "Available actions: " .. actions_str()
	end
	local action_spec = actions_table[action_name] or actions_aliases[action_name]
	if not action_spec then
		return nil, ("Unknown action `%s`\nAvailable actions: %s"):format(action_name, actions_str())
	end
	return ("/wp %s %s"):format(action_name, action_spec.usage)
end

local function cmd_create(plname, param_group, ...)
	local param_name = table.concat({...}, " ")
	local groupid = nil
	if param_group then
		groupid = pmutils.get_group_id_by_name(param_group)
	end
	if not groupid then
		groupid = (group_waypoints.get_defaults_for_player(plname) or {}).groupid
	end
	if not groupid then
		return nil, "Cannot create waypoint: No group specified, and no default group found. Usage: /wp new [group] [name]"
	end

	local group_name = pmutils.get_group_name(groupid)
	if not group_name then
		error("Group id " .. groupid .. " not found")
	end

	local player = minetest.get_player_by_name(plname)
	local wp =
		group_waypoints.create_waypoint {
		name = param_name,
		pos = player:get_pos(),
		groupid = groupid,
		creator = plname
	}

	local defaults = group_waypoints.get_defaults_for_player(plname) or {}
	defaults.groupid = wp.groupid
	group_waypoints.set_defaults_for_player(plname, defaults)

	return ("Created waypoint `%s` at %s in group `%s`"):format(
		wp.name,
		utils.pos_to_str(wp.pos),
		group_name)
end

local function cmd_manage(plname, param)
	-- TODO pre-select group filter
	group_waypoints.show_wplist_formspec(plname)
	return "Opening waypoint management form..."
end

actions_table.new = {
	aliases = {"create"},
	fn = cmd_create,
	usage = "[group] [name] - Create a waypoint in that group, at the current position, and give it a name (optional)."
}
actions_table.manage = {
	aliases = {"list", "show", "gui"},
	fn = cmd_manage,
	usage = "[group] - Open a GUI to manage all waypoints in that group, or across all groups."
}
actions_table.help = {
	fn = cmd_help,
	usage = "[action] - Show all available command actions, or info for a particular action."
}

for action_name, action_spec in pairs(actions_table) do
	for _, alias in ipairs(action_spec.aliases or {}) do
		actions_aliases[alias] = action_spec
	end
end

local function handle_cmd(plname, raw_params)
	local params = {}
	for chunk in string.gmatch(raw_params, "[^%s]+") do
		table.insert(params, chunk)
	end

	if #params == 0 then
		return nil, "Usage: /wp <action> [parameters...]\nAvailable actions: " .. actions_str()
	end

	local action_name = table.remove(params, 1)
	local action_spec = actions_table[action_name]
	if not action_spec then
		action_spec = actions_aliases[action_name]
	end
	if not action_spec then
		return nil, "Unknown action: `" .. action_name .. "` See `/wp help` for all available actions."
	end

	return action_spec.fn(plname, unpack(params))
end

local wp_cmd = {
	params = "<action> [parameters...]",
	description = "Waypoint management. For more info: /wp help",
	func = function(plname, raw_params)
		local ok_msg, err_msg = handle_cmd(plname, raw_params)
		if not ok_msg and not err_msg then
			ok_msg = "Command executed successfully: " .. raw_params
		end
		if ok_msg then
			minetest.chat_send_player(plname, ok_msg)
		end
		if err_msg then
			minetest.chat_send_player(plname, "Error: " .. err_msg)
		end
		return not err_msg
	end
}

minetest.register_chatcommand("wp", wp_cmd)
minetest.register_chatcommand("waypoint", wp_cmd)
minetest.register_chatcommand("waypoints", wp_cmd)
