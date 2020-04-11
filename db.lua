-- This module handles loading/storing all mod state from/to Postgres.

local insecure_env = (...).insecure_env
local u = pmutils

local exports = {}

--=== postgres connection ===--

local driver_exists, driver = pcall(insecure_env.require, "luasql.postgres")
if not driver_exists then
	error("[group_waypoints] Lua PostgreSQL driver not found. " ..
		"Please install it (try 'luarocks install luasql-postgres').")
end

local db = nil
local env = nil

local sourcename = minetest.settings:get("group_waypoints_db_sourcename")
local username = minetest.settings:get("group_waypoints_db_username")
local password = minetest.settings:get("group_waypoints_db_password")

local function prep_db()
	env = assert (driver.postgres())
	db = assert (env:connect(sourcename, username, password))

	-- use BIGINT instead of TIMESTAMP WITH TIME ZONE because I cannot
	-- find documentation on how luasql handles the timestamp format
	assert(u.prepare(db, [[
		CREATE TABLE IF NOT EXISTS waypoints (
			id VARCHAR(16) NOT NULL,
			groupid VARCHAR(16) NOT NULL,
			creator VARCHAR(32) NOT NULL,
			created_at BIGINT NOT NULL,
			x INTEGER NOT NULL,
			y INTEGER NOT NULL,
			z INTEGER NOT NULL,
			name TEXT NOT NULL,
			PRIMARY KEY (id)
		)]]))

	assert(u.prepare(db, [[
		CREATE TABLE IF NOT EXISTS waypoint_player_overrides (
			waypoint_id VARCHAR(16) REFERENCES waypoints(id),
			player_name VARCHAR(32) NOT NULL,
			visible BOOLEAN NOT NULL DEFAULT TRUE,
			PRIMARY KEY (waypoint_id, player_name)
		)]]))
end

prep_db()

minetest.register_on_shutdown(function()
	db:close()
	env:close()
end)

--=== waypoints ===--

local QUERY_GET_ALL_WAYPOINTS = [[
	SELECT * FROM waypoints
]]

function exports.load_all_waypoints()
	local cur = u.prepare(db, QUERY_GET_ALL_WAYPOINTS)
	local waypoints = {}
	local row = cur:fetch({}, "a")
	while row do
		table.insert(waypoints, {
			id = row.id,
			groupid = row.groupid,
			creator = row.creator,
			created_at = row.created_at,
			pos = {x = row.x, y = row.y, z = row.z},
			name = row.name,
			color = row.color
		})
		row = cur:fetch(row, "a")
	end
	return waypoints
end

local QUERY_INSERT_WAYPOINT = [[
	INSERT INTO waypoints (id, groupid, creator, created_at, x, y, z, name)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT (id) DO UPDATE SET
	groupid = EXCLUDED.groupid,
	creator = EXCLUDED.creator,
	x = EXCLUDED.x,
	y = EXCLUDED.y,
	z = EXCLUDED.z,
	name = EXCLUDED.name
]]

function exports.store_waypoint(waypoint)
	return assert(u.prepare(db, QUERY_INSERT_WAYPOINT,
		waypoint.id,
		waypoint.groupid,
		waypoint.creator,
		waypoint.created_at,
		waypoint.pos.x,
		waypoint.pos.y,
		waypoint.pos.z,
		waypoint.name))
end

local QUERY_DELETE_WAYPOINT = [[
	DELETE FROM waypoints
	WHERE id = ?
]]

local QUERY_DELETE_WAYPOINT_OVERRIDES = [[
	DELETE FROM waypoint_player_overrides
	WHERE waypoint_id = ?
]]

function exports.delete_waypoint(wpid)
	assert(u.prepare(db, QUERY_DELETE_WAYPOINT_OVERRIDES, wpid))
	assert(u.prepare(db, QUERY_DELETE_WAYPOINT, wpid))
end

--=== waypoint_player_overrides ===--

local QUERY_GET_ALL_WAYPOINT_PLAYER_OVERRIDES = [[
	SELECT * FROM waypoint_player_overrides
]]

function exports.load_all_waypoint_player_overrides()
	local cur = u.prepare(db, QUERY_GET_ALL_WAYPOINT_PLAYER_OVERRIDES)
	local overrides = {}
	local row = cur:fetch({}, "a")
	while row do
		table.insert(overrides, {
			waypoint_id = row.waypoint_id,
			player_name = row.player_name,
			visible = row.visible
		})
		row = cur:fetch(row, "a")
	end
	return overrides
end

local QUERY_INSERT_WAYPOINT_PLAYER_OVERRIDE = [[
	INSERT INTO waypoint_player_overrides (waypoint_id, player_name, visible)
	VALUES (?, ?, ?)
	ON CONFLICT (waypoint_id, player_name) DO UPDATE SET
	visible = EXCLUDED.visible
]]

function exports.store_waypoint_player_override(waypoint_id, player_name, override)
	return assert(u.prepare(db, QUERY_INSERT_WAYPOINT_PLAYER_OVERRIDE,
		waypoint_id, player_name, override.visible))
end

--=== event handlers ===--

group_waypoints.on_waypoint_created(
	function(waypoint)
		exports.store_waypoint(waypoint)
	end
)

group_waypoints.on_waypoint_updated(
	function(waypoint)
		exports.store_waypoint(waypoint)
	end
)

group_waypoints.on_waypoint_deleted(
	function(waypoint)
		exports.delete_waypoint(waypoint.id)
	end
)

group_waypoints.on_waypoint_setting_updated(
	function(event)
		exports.store_waypoint_player_override(event.wpid, event.plname, event.config)
	end
)

return exports
