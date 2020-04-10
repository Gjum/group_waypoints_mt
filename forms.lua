-- This module displays forms and handles fields sent by the client.

local pmutils = (...).pmutils

local exports = {}

local player_form_states = {}

local function pluralize(num, str, plural)
	if num == 1 then
		return num .. str
	else
		return num .. str .. plural
	end
end

local day_seconds = 24 * 60 * 60
local function format_age(age)
	if age < 0 then
		return "(future)"
	elseif age < 5 then
		return "just now"
	elseif age < 60 then
		return pluralize(math.floor(age), " second", "s")
	elseif age < 60 * 60 then
		return pluralize(math.floor(age / 60), " minute", "s")
	elseif age < day_seconds then
		return pluralize(math.floor(age / 60 / 60), " hour", "s")
	elseif age < 7 * day_seconds then
		return pluralize(math.floor(age / day_seconds), " day", "s")
	elseif age < 30 * day_seconds then
		return pluralize(math.floor(age / day_seconds / 7), " week", "s")
	else
		return pluralize(math.floor(age / day_seconds / 30), " month", "s")
	end
end

local hl_color = "#466432" -- bgcolor in selected row, fg color in previously selected rows

local columns = {
	{name = "#888888", type = "color", no_sort_indicator = true},
	{name = "Visible", sort_key = "visible", type = "text,align=center"},
	{name = "X", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Y", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Z", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Distance", sort_key = "distance", type = "text,align=right"},
	{name = "Waypoint Name", sort_key = "name", type = "text"},
	{name = "Group", sort_key = "group", type = "text"},
	{name = "Creator", sort_key = "creator", type = "text"},
	{name = "Age", sort_key = "age", type = "text"}
}

local table_column_types = {}
for i, column in ipairs(columns) do
	local col_spec = column.type
	if i > 2 then
		col_spec = col_spec .. ",padding=1"
	end
	table_column_types[i] = col_spec
end

-- table key -> display name
local sort_methods_names = {
	visible = "Visible",
	distance = "Distance",
	name = "Waypoint Name",
	group = "Group",
	creator = "Creator",
	age = "Age"
}

local function build_table_cells(plname, state)
	assert(sort_methods_names[state.sort_key], "Unknown sort method: " .. dump2(state.sort_key))

	local player = minetest.get_player_by_name(plname)
	assert(player, "Unknown player name: " .. plname)
	local player_pos = player:get_pos()
	local waypoints = group_waypoints.get_waypoints_for_player(plname)

	local now = os.time()
	local sorted_waypoints = {}
	for wpid, waypoint in pairs(waypoints) do
		local s_wp = {}
		s_wp.waypoint = waypoint
		s_wp.group_name = pmutils.get_group_name(waypoint.groupid)
		if group_waypoints.get_waypoint_visible_for_player(plname, wpid) then
			if group_waypoints.get_group_visible_for_player(plname, waypoint.groupid) then
				s_wp.visible_text = "shown"
				s_wp.visible = 1
			else
				s_wp.visible_text = "hidden (group)"
				s_wp.visible = 2
			end
		else
			s_wp.visible_text = "hidden"
			s_wp.visible = 3
		end
		s_wp.distance = vector.distance(waypoint.pos, player_pos)
		s_wp.name = waypoint.name:lower()
		s_wp.group = s_wp.group_name:lower()
		s_wp.creator = waypoint.creator:lower()
		s_wp.age = now - waypoint.created_at
		sorted_waypoints[#sorted_waypoints + 1] = s_wp
	end

	table.sort(
		sorted_waypoints,
		function(a, b)
			if state.sort_descending then
				return a[state.sort_key] > b[state.sort_key]
			else -- ascending
				return a[state.sort_key] < b[state.sort_key]
			end
		end
	)

	local table_cells = {}

	-- table header row
	for col_nr, column in ipairs(columns) do
		local column_name = column.name
		if column.sort_key == state.sort_key and not column.no_sort_indicator then
			-- indicate that we're sorting by this column
			if state.sort_descending then
				column_name = "▲ " .. column.name
			else
				column_name = "▼ " .. column.name
			end
		end
		table_cells[#table_cells + 1] = minetest.formspec_escape(column_name)
	end

	-- waypoint rows
	state.waypoints_by_row = {}
	for row_nr, s_wp in ipairs(sorted_waypoints) do
		local waypoint = s_wp.waypoint
		state.waypoints_by_row[row_nr + 1] = waypoint -- first row is table header
		local text_color = ""
		if s_wp.visible_text ~= "shown" then
			text_color = "#aaaaaa"
		end
		-- TODO color from bulk selection
		table_cells[#table_cells + 1] = text_color
		table_cells[#table_cells + 1] = minetest.formspec_escape(s_wp.visible_text)
		table_cells[#table_cells + 1] = minetest.formspec_escape(waypoint.pos.x)
		table_cells[#table_cells + 1] = minetest.formspec_escape(waypoint.pos.y)
		table_cells[#table_cells + 1] = minetest.formspec_escape(waypoint.pos.z)
		table_cells[#table_cells + 1] = minetest.formspec_escape(math.ceil(s_wp.distance))
		table_cells[#table_cells + 1] = minetest.formspec_escape(waypoint.name)
		table_cells[#table_cells + 1] = minetest.formspec_escape(s_wp.group_name)
		table_cells[#table_cells + 1] = minetest.formspec_escape(waypoint.creator)
		table_cells[#table_cells + 1] = minetest.formspec_escape(format_age(s_wp.age))
	end

	return table_cells
end

function exports.show_wplist_formspec(plname)
	local state = player_form_states[plname] or {}
	player_form_states[plname] = state
	state.sort_key = state.sort_key or "distance"

	local table_cells = build_table_cells(plname, state)

	-- form sizes
	local ww = 15 -- window width
	local tch = 3 -- top controls height
	local th = 10 -- table height

	local formspec = {
		"formspec_version[2]",
		"size[" .. ww .. "," .. (tch + th) .. ",false]",
		"real_coordinates[true]",
		"button_exit[" .. (ww - 0.5) .. ",0;0.5,0.5;close;X]",
		-- TODO filter by group, creator
		-- TODO filter by text in name
		-- TODO label to tell user to sort by clicking table header
		"tablecolumns[" .. table.concat(table_column_types, ";") .. "]",
		("table[0.5,%s;%s,%s;wp_table;%s;%s]"):format(
			tch,
			ww - 1,
			th,
			table.concat(table_cells, ","),
			state.row_selected or ""
		)
	}
	formspec = table.concat(formspec)
	minetest.show_formspec(plname, "group_waypoints:wplist", formspec)
end

local function handle_sort_clicked(state, column)
	local prev_sort = state.sort_key
	state.sort_key = column.sort_key
	if prev_sort ~= state.sort_key then
		-- changing sort column uses ascending sort
		state.sort_descending = false
	else
		-- clicking sorted column reverses the sort order
		state.sort_descending = not state.sort_descending
	end
end

local function toggle_waypoint_visibility(plname, waypoint)
	if group_waypoints.get_waypoint_visible_for_player(plname, waypoint.id) then
		if group_waypoints.get_group_visible_for_player(plname, waypoint.groupid) then
			-- is visible, make invisible
			group_waypoints.set_waypoint_visible_for_player(plname, waypoint.id, false)
		else
			-- is visible but group is invisible. make group visible
			group_waypoints.set_group_visible_for_player(plname, waypoint.groupid, true)
		end
	else
		-- invisible. make waypoint and its group visible
		group_waypoints.set_waypoint_visible_for_player(plname, waypoint.id, true)
		group_waypoints.set_group_visible_for_player(plname, waypoint.groupid, true)
	end
end

minetest.register_on_player_receive_fields(
	function(player, formname, fields)
		if formname ~= "group_waypoints:wplist" then
			return
		end
		local plname = player:get_player_name()
		local state = player_form_states[plname]
		if not state then
			minetest.log(("Player %s sent form fields for `%s` without opening"):format(plname, formname))
			return
		end
		if fields.close then
			player_form_states[plname] = nil
			return
		end
		if fields.wp_table then
			local tf = minetest.explode_table_event(fields.wp_table)
			if tf.type == "CHG" then
				local column = columns[tf.column]
				if not column then
					minetest.log(("Player %s sent form fields for `%s` table with invalid column nr %d"):format(plname, formname, tf.column))
					-- refresh, allow player to click again
					exports.show_wplist_formspec(plname)
					return
				end

				if tf.row == 1 then
					handle_sort_clicked(state, column)
					exports.show_wplist_formspec(plname)
					state.row_selected = nil -- don't highlight first row
				else
					local waypoint = (state.waypoints_by_row or {})[tf.row]
					if not waypoint then
						minetest.log(("Player %s sent form fields for `%s` table with invalid row nr %d"):format(plname, formname, tf.row))
						-- refresh, allow player to click again
						exports.show_wplist_formspec(plname)
						return
					end
					state.row_selected = tf.row

					local column_name = column.name
					if column_name == "Group" then
						-- TODO filter by group by clicking on group
					elseif column_name == "Creator" then
						-- TODO filter by creator by clicking on creator
					elseif column_name == "Visible" then
						toggle_waypoint_visibility(plname, waypoint)
					end

					exports.show_wplist_formspec(plname)
				end
			else
				-- TODO handle other table event types
			end
			return
		elseif fields.search_name then
		-- TODO filter by name (free text)
		end
	end
)

return exports
