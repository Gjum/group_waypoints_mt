unused_args = false
allow_defined_top = true

globals = {
	"pm",
	"group_waypoints"
}

read_globals = {
	string = {fields = {"split"}},
	table = {fields = {"copy", "getn"}},
	"strsub",
	-- civtest
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
