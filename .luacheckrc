unused_args = false
allow_defined_top = true

globals = {
	"group_waypoints"
}

read_globals = {
	string = {fields = {"split"}},
	table = {fields = {"copy", "getn"}},
	-- civtest
	"pm",
	"pmutils",
	-- Builtin
	"DIR_DELIM",
	"dump",
	"ItemStack",
	"Settings",
	"vector",
	"VoxelArea",
	-- MTG
	"creative",
	"default",
	"sfinv",
	-- minetest
	"dump2",
	"minetest"
}
