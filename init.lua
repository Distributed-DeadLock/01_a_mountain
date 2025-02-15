-- 01_a_mountain : Just a Mountain
-- adds a 2000x4000 blocks-large & 1000 blocks-high mountain on worldgen
-- author : Distributed-DeadLock
-- dependencies : default
-- ----------------------------------------------------------------------------
-- Config Section ---

local mountain_base_x = tonumber(core.setting_get("01_a_mountain.x")) or 1000
local mountain_base_z = tonumber(core.setting_get("01_a_mountain.z")) or 2000

local mountain_base_xdim = 1000
local mountain_base_zdim = 2000

-- get the size of chunks to be generated at once by mapgen, stated in nodes
local chunksizeinnodes = core.setting_get("chunksize") * 16
local mysettings = core.settings
mysettings:set("01_a_mountain.chunksizeinnodes", chunksizeinnodes)

local modpath = core.get_modpath("01_a_mountain")
core.register_mapgen_script(modpath .. "/mapgen.lua")


-- apply game/med specific patches to ore/decoration generation
local gameinfo = core.get_game_info()
local y_fix = 0
local y_pretend = 0
if core.get_modpath("mcl_biomes") then
y_fix = 1
y_pretend = -90
end
if (gameinfo.id == "nodecore") then
	y_fix = 1
	y_pretend = -120
end
if (gameinfo.id == "mineclonia") then
	mysettings:set("01_a_mountain.skip_decor", 1)
else
	mysettings:set("01_a_mountain.skip_decor", 0)
end

local do_boostedgen = true
if (gameinfo.id == "exile") then
	do_boostedgen = false
end

local liquid_filter = {}
local c_air
local function fill_filter()
	c_air = core.get_content_id("air")
	liquid_filter.a = core.get_content_id("mapgen_water_source")
	liquid_filter.b = core.get_content_id("mapgen_water_source")
	if (core.registered_nodes["mapgen_lava_source"]) then
		liquid_filter.b = core.get_content_id("mapgen_lava_source")
	end
	if (core.registered_nodes["nc_terrain:water_source"]) then
		liquid_filter.b = core.get_content_id("nc_terrain:water_source")
	end
	if (core.registered_nodes["nc_terrain:lava_source"]) then
		liquid_filter.b = core.get_content_id("nc_terrain:lava_source")
	end
	if (core.registered_nodes["mcl_core:lava_source"]) then
		liquid_filter.b = core.get_content_id("mcl_core:lava_source")
	end
	if (liquid_filter.b == c_air) then
		liquid_filter.b = liquid_filter.a
	end
end

local function oregen_mirror(minp, maxp, seed)
	-- if the chunk does not contain a x ,y & z position the mountain should be at, exit and do nothing.	
	if ( math.abs(((minp.x + maxp.x) / 2) - mountain_base_x) >= (mountain_base_xdim + 100) ) then
		return
	end	
	if ( math.abs(((minp.z + maxp.z) / 2) - mountain_base_z) >= (mountain_base_zdim + 100) ) then
		return
	end	
	if ( (minp.y > 1000) or (minp.y < 0) ) then
		return
	end
	
	-- get the voxel manipulation object for the chunk
	local voxman_o = core.get_mapgen_object("voxelmanip")
	-- get the heightmap object for the chunk
	local hmap = core.get_mapgen_object("heightmap")
	-- get the biomemap object for the chunk
	local bmap = core.get_mapgen_object("biomemap")	
	-- get the emerged area, the actual area that is represented by the voxelmanip obj
	local emin, emax = voxman_o:get_emerged_area()
	-- get voxelarea helper 
	local voxarea = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	-- load nodes into array
	local data = voxman_o:get_data()

	-- get the helper voxel manip obj for ore generation
	local g_minp = minp
	local g_maxp = maxp
	local g_height = g_maxp.y - g_minp.y
	-- adjust the pretend_y value according to hosting game
	if (y_fix == 1) then
		g_minp.y = y_pretend
	else
		g_minp.y = (g_minp.y + 400) * -1
	end
	g_maxp.y = (g_minp.y + g_height)

	local g_voxman_o = VoxelManip(g_minp,g_maxp)
	local g_data = g_voxman_o:get_data()
	local g_emin, g_emax = g_voxman_o:get_emerged_area()
	local g_voxarea = VoxelArea:new{
		MinEdge = g_emin,
		MaxEdge = g_emax
	}
		
	-- loop the mapchunk to copy the data
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				-- vi, voxel indexing object 
				local vi = voxarea:index(x, y, z)
				local g_vi = g_voxarea:index(x, y, z)
				g_data[g_vi] = data[vi]
			end
		end
	end
	-- write the map data
	g_voxman_o:set_data(g_data)
	
	-- generate ores	
	core.generate_ores(g_voxman_o)
	
	g_data = g_voxman_o:get_data()
	-- loop the mapchunk to copy the data
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				-- vi, voxel indexing object 
				local vi = voxarea:index(x, y, z)
				local g_vi = g_voxarea:index(x, y, z)
				-- copy, but filter lava & water
				if ((g_data[g_vi] == liquid_filter.a) or (g_data[g_vi] == liquid_filter.b)) then
					data[vi] = c_air
				else
					data[vi] = g_data[g_vi]
				end
			end
		end
	end		
	
	-- write the map data
	voxman_o:set_data(data)	

	voxman_o:calc_lighting()
	voxman_o:write_to_map(true)
end

core.register_on_mods_loaded(fill_filter)

if do_boostedgen then
	core.register_on_generated(oregen_mirror)
end