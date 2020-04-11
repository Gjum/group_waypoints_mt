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
	{name = "Name", sort_key = "name", type = "text"},
	{name = "Group", sort_key = "group", type = "text"},
	{name = "Creator", sort_key = "creator", type = "text"},
	{name = "Age", sort_key = "age", type = "text"},
	{name = "Delete", sort_key = "delete", type = "text"}
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
	age = "Age",
	delete = "Delete"
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

		s_wp.delete = "" -- no permission
		if (state.waypoints_marked_for_deletion or {})[waypoint.id] then
			s_wp.delete = "Undo"
		elseif group_waypoints.can_player_delete_waypoint(plname, waypoint) then
			s_wp.delete = "Delete"
		end

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
		if s_wp.delete == "Undo" then
			text_color = "#dd2200"
		elseif s_wp.visible_text ~= "shown" then
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
		table_cells[#table_cells + 1] = minetest.formspec_escape(s_wp.delete)
	end

	return table_cells
end

local function get_selected_waypoint(state)
	if not state.row_selected or not state.waypoints_by_row then
		return nil
	end
	return state.waypoints_by_row[state.row_selected]
end

function exports.show_wplist_formspec(plname)
	local state = player_form_states[plname] or {}
	player_form_states[plname] = state
	state.sort_key = state.sort_key or "distance"

	local selected_waypoint = get_selected_waypoint(state)

	local table_cells = build_table_cells(plname, state)

	-- form and elements sizes and positioning
	local ww = 15 -- window width
	local tch = 1.25
	local th = 5 -- table height
	local wh = 0.25 + tch + 0.25 + th + 0.25 -- window height
	local ty = 0.25 + tch + 0.25 -- table start y coord

	local wp_editor
	if selected_waypoint then
		state.waypoint_editor_text = state.waypoint_editor_text or ("%d %d %d %s"):format(
			selected_waypoint.pos.x,
			selected_waypoint.pos.y,
			selected_waypoint.pos.z,
			selected_waypoint.name
		)
		wp_editor = {
			("label[0.25,0.5;Edit waypoint in group \\[%s\\] by %s]"):format(
				minetest.formspec_escape(pmutils.get_group_name(selected_waypoint.groupid)),
				minetest.formspec_escape(selected_waypoint.creator)
			),
			"field[0.25,0.75;" .. (ww - 2.5) .. ",0.5;waypoint_editor;;"
				.. minetest.formspec_escape(state.waypoint_editor_text) .. "]",
			"field_close_on_enter[waypoint_editor;false]",
			"button[" .. (ww - 2.25) .. ",0.75;2,0.5;update_waypoint;Update]",
		}
		if state.waypoint_editor_error then
			wp_editor[#wp_editor + 1] = "label[0.5,1.5;" .. minetest.formspec_escape(state.waypoint_editor_error) .. "]"
		end
	else
		wp_editor = {
			"label[0.25,1;Select a waypoint to edit it]"
		}
	end
	state.waypoint_editor_error = nil

	local formspec = {
		"formspec_version[2]",
		"size[" .. ww .. "," .. wh .. ",false]",
		"real_coordinates[true]",
		"button_exit[" .. (ww - 0.5) .. ",0;0.5,0.5;close;X]",
		table.concat(wp_editor),
		-- TODO filter by group, creator
		-- TODO filter by text in name
		-- TODO label to tell user to sort by clicking table header
		"tableoptions[highlight=#555555]",
		"tablecolumns[" .. table.concat(table_column_types, ";") .. "]",
		("table[0.25,%s;%s,%s;wp_table;%s;%s]"):format(
			ty,
			ww - 0.5,
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

local function toggle_mark_waypoint_for_deletion(plname, state, waypoint)
	if not group_waypoints.can_player_delete_waypoint(plname, waypoint) then
		return
	end
	local marked = state.waypoints_marked_for_deletion or {}
	if marked[waypoint.id] then
		marked[waypoint.id] = nil -- undo was clicked
	else
		marked[waypoint.id] = waypoint
	end
	state.waypoints_marked_for_deletion = marked
end

local function handle_waypoints_table(plname, fields, state)
	if not fields.wp_table then
		return -- something else changed in the form
	end

	local tf = minetest.explode_table_event(fields.wp_table)
	if tf.type ~= "CHG" then
		return -- other table event
	end

	local column = columns[tf.column]
	if not column then
		minetest.log(("Player %s sent form fields for `group_waypoints:wplist` table with invalid column nr %d"):format(plname, tf.column))
		-- refresh, allow player to click again
		exports.show_wplist_formspec(plname)
		return
	end

	if state.row_selected ~= tf.row then -- changing selection
		state.waypoint_editor_text = nil -- override any user-entered text
	end

	if tf.row == 1 then
		handle_sort_clicked(state, column)
		exports.show_wplist_formspec(plname)
		state.row_selected = nil -- don't highlight table header
	else
		local waypoint = (state.waypoints_by_row or {})[tf.row]
		if not waypoint then
			minetest.log(("Player %s sent form fields for `group_waypoints:wplist` table with invalid row nr %d"):format(plname, tf.row))
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
		elseif column_name == "Delete" then
			toggle_mark_waypoint_for_deletion(plname, state, waypoint)
		end

		exports.show_wplist_formspec(plname)
	end
end

local function handle_waypoint_editor(plname, fields, state)
	if not fields.waypoint_editor then
		return -- something else changed in the form
	end

	state.waypoint_editor_text = fields.waypoint_editor

	if not fields.update_waypoint and not fields.key_enter_field == "waypoint_editor" then
		return -- the editor contains text but the waypoint should not be updated yet
	end

	local waypoint = get_selected_waypoint(state)
	if not waypoint then
		minetest.log(("Player %s tried updating waypoint in `group_waypoints:wplist` while no waypoint is selected"):format(plname))
		-- refresh to resolve inconsistent state
		exports.show_wplist_formspec(plname)
		return
	end

	local xs, ys, zs, name = fields.waypoint_editor:match("(-?%d+),? +(-?%d+),? +(-?%d+),? *(.*)")
	local pos = {x=tonumber(xs), y=tonumber(ys), z=tonumber(zs)}
	if pos.x == nil or pos.y == nil or pos.z == nil then
		state.waypoint_editor_error = "Please specify the position at the beginning: 1 -22 345 My Waypoint Name"
		exports.show_wplist_formspec(plname)
		return
	end

	group_waypoints.set_waypoint_pos(plname, waypoint.id, pos)
	group_waypoints.set_waypoint_name(plname, waypoint.id, name)

	exports.show_wplist_formspec(plname)
end

minetest.register_on_player_receive_fields(
	function(player, formname, fields)
		if formname ~= "group_waypoints:wplist" then
			return -- other form changed
		end

		local plname = player:get_player_name()
		local state = player_form_states[plname]
		if not state then
			minetest.log(("Player %s sent form fields for `%s` without opening"):format(plname, formname))
			return
		end

		if fields.quit or fields.close then
			for wpid, waypoint in pairs(state.waypoints_marked_for_deletion or {}) do
				group_waypoints.delete_waypoint(plname, wpid)
			end
			player_form_states[plname] = nil
			return
		end

		handle_waypoints_table(plname, fields, state)

		handle_waypoint_editor(plname, fields, state)

		if fields.search_name then
			-- TODO filter by name (free text)
		end
	end
)

return exports
