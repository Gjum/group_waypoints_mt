-- This module displays forms and handles fields sent by the client.

local pm_shim = (...).pm_shim

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

local columns = {
	{name = "#888888", type = "color", no_sort_indicator = true},
	{name = "Select", sort_key = "selected", type = "text,align=center"},
	{name = "Visible", sort_key = "visible", type = "text,align=center"},
	{name = "X", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Y", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Z", sort_key = "distance", type = "text,align=right", no_sort_indicator = true},
	{name = "Distance", sort_key = "distance", type = "text,align=right"},
	{name = "Name", sort_key = "name", type = "text"},
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
	selected = "Selected",
	visible = "Visible",
	distance = "Distance",
	name = "Name",
	group = "Group",
	creator = "Creator",
	age = "Age"
}

local function get_selected_waypoint(state)
	if not state.row_selected or not state.waypoints_by_row then
		return nil
	end
	return state.waypoints_by_row[state.row_selected]
end

--- state.selected_waypoints plus state.row_selected
local function get_all_selected_waypoints(state)
	local all = {}
	local empty = true
	for wpid, waypoint in pairs(state.selected_waypoints or {}) do
		all[wpid] = waypoint
		empty = false
	end
	if empty then
		local selected_waypoint = get_selected_waypoint(state)
		if selected_waypoint then
			all[selected_waypoint.id] = selected_waypoint
		end
	end
	return all
end

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
		s_wp.group_name = pm_shim.get_group_name(waypoint.groupid)

		s_wp.selected = ""
		if (state.selected_waypoints or {})[waypoint.id] then
			s_wp.selected = "o"
		end

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
		if s_wp.selected == "o" then
			text_color = "#ace673"
		elseif s_wp.visible_text ~= "shown" then
			text_color = "#aaaaaa"
		end
		table_cells[#table_cells + 1] = text_color
		table_cells[#table_cells + 1] = minetest.formspec_escape(s_wp.selected)
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

	local selected_waypoint = get_selected_waypoint(state)

	local table_cells = build_table_cells(plname, state)

	-- form and elements sizes and positioning
	local ww = 15 -- window width
	local tch = 1.25
	local th = 5 -- table height
	local ty = 0.25 + tch + 0.25 -- table start y coord
	local btny = ty + th + 0.25 -- buttons start y coord
	local wh = btny + 0.5 + 0.25 -- window height

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
				minetest.formspec_escape(pm_shim.get_group_name(selected_waypoint.groupid)),
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
			"label[1,1;Select a waypoint to edit it]"
		}
	end

	local num_selected_showable = 0
	local num_selected_hideable = 0
	local num_selected_deletable = 0
	for wpid, waypoint in pairs(get_all_selected_waypoints(state) or {}) do
		local is_visible = group_waypoints.get_waypoint_visible_for_player(plname, waypoint.id)
			and group_waypoints.get_group_visible_for_player(plname, waypoint.groupid)
		if is_visible then
			num_selected_hideable = num_selected_hideable + 1
		else
			num_selected_showable = num_selected_showable + 1
		end
		if group_waypoints.can_player_delete_waypoint(plname, waypoint) then
			num_selected_deletable = num_selected_deletable + 1
		end
	end

	local formspec = {
		"formspec_version[2]",
		"size[" .. ww .. "," .. wh .. ",false]",
		"real_coordinates[true]",
		"button_exit[" .. (ww - 0.5) .. ",0;0.5,0.5;close;X]",
		table.concat(wp_editor),
		-- TODO filter by group, creator
		-- TODO filter by text in name
		-- TODO label to tell user to sort by clicking table header
		"tableoptions[highlight=#466432]",
		"tablecolumns[" .. table.concat(table_column_types, ";") .. "]",
		("table[0.25,%s;%s,%s;wp_table;%s;%s]"):format(
			ty,
			ww - 0.5,
			th,
			table.concat(table_cells, ","),
			state.row_selected or ""
		),
		("button[0.25,%f;2.5,0.5;btn_show_selected;Show %d selected]"):format(btny, num_selected_showable),
		("button[3,%f;2.5,0.5;btn_hide_selected;Hide %d selected]"):format(btny, num_selected_hideable),
		("button[5.75,%f;2.5,0.5;btn_delete_selected;Delete %d selected]"):format(btny, num_selected_deletable),
		("button_exit[%f,%f;2.5,0.5;close;Close]"):format(ww - 2.75, btny),
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

local function toggle_waypoint_selected(plname, state, waypoint)
	local selected = state.selected_waypoints or {}
	if selected[waypoint.id] then
		selected[waypoint.id] = nil
	else
		selected[waypoint.id] = waypoint
	end
	state.selected_waypoints = selected
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

	if state.row_selected ~= tf.row then -- changing selection
		state.waypoint_editor_text = nil -- override any user-entered text
	end

	if tf.row == 1 then
		if column then
			handle_sort_clicked(state, column)
			exports.show_wplist_formspec(plname)
			state.row_selected = nil -- don't highlight table header
		end
	else
		local waypoint = (state.waypoints_by_row or {})[tf.row]
		if not waypoint then
			minetest.log(("Player %s sent form fields for `group_waypoints:wplist` table"
				.. " with invalid row nr %d"):format(plname, tf.row))
			-- refresh, allow player to click again
			exports.show_wplist_formspec(plname)
			return
		end
		state.row_selected = tf.row

		local column_name = (column or {}).name
		if column_name == "Visible" then
			toggle_waypoint_visibility(plname, waypoint)
		elseif column_name == "Select" then
			toggle_waypoint_selected(plname, state, waypoint)
		end

		exports.show_wplist_formspec(plname)
	end
end

local function handle_waypoint_editor(plname, fields, state)
	if not fields.waypoint_editor then
		return -- something else changed in the form
	end

	state.waypoint_editor_text = fields.waypoint_editor

	state.waypoint_editor_error = nil

	local waypoint = get_selected_waypoint(state)
	if not waypoint then
		minetest.log(("Player %s tried updating waypoint in `group_waypoints:wplist`"
			.. " while no waypoint is selected"):format(plname))
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

	if not fields.update_waypoint and fields.key_enter_field ~= "waypoint_editor" then
		return -- the editor contains text but the waypoint should not be updated yet
	end

	group_waypoints.set_waypoint_pos(plname, waypoint.id, pos)
	group_waypoints.set_waypoint_name(plname, waypoint.id, name)

	exports.show_wplist_formspec(plname)
end

local function handle_buttons(plname, fields, state)
	if fields.btn_show_selected then
		local visible_groups = {}
		for wpid, waypoint in pairs(get_all_selected_waypoints(state)) do
			group_waypoints.set_waypoint_visible_for_player(plname, waypoint.id, true)
			visible_groups[waypoint.groupid] = true
		end
		for groupid, _ in pairs(visible_groups) do
			group_waypoints.set_group_visible_for_player(plname, groupid, true)
		end
		exports.show_wplist_formspec(plname)
	elseif fields.btn_hide_selected then
		-- TODO consider: if hiding all in a group, just hide group instead of each waypoint individually
		for wpid, waypoint in pairs(get_all_selected_waypoints(state)) do
			group_waypoints.set_waypoint_visible_for_player(plname, waypoint.id, false)
		end
		exports.show_wplist_formspec(plname)
	elseif fields.btn_delete_selected then
		for wpid, waypoint in pairs(get_all_selected_waypoints(state)) do
			group_waypoints.delete_waypoint(plname, wpid)
		end
		exports.show_wplist_formspec(plname)
	end
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
			player_form_states[plname] = nil
			return
		end

		handle_buttons(plname, fields, state)

		handle_waypoints_table(plname, fields, state)

		handle_waypoint_editor(plname, fields, state)
	end
)

return exports
