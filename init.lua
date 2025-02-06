-- 01_a_mountain : Just a Mountain
-- adds a 2000x4000 blocks-large & 1000 blocks-high mountain on worldgen
-- author : Distributed-DeadLock
-- dependencies : default
-- ----------------------------------------------------------------------------
-- Config Section ---

local mountain_base_x = tonumber(core.setting_get("01_a_mountain.x")) or 1000
local mountain_base_z = tonumber(core.setting_get("01_a_mountain.z")) or 2000

local mountain_orefactor = tonumber(core.setting_get("01_a_mountain.orefactor")) or 9
local mountain_above_y = tonumber(core.setting_get("01_a_mountain.above_y")) or -500

local mountain_base_xdim = 1000
local mountain_base_zdim = 2000

-- get the size of chunks to be generated at once by mapgen, stated in nodes
local chunksizeinnodes = minetest.setting_get("chunksize") * 16

local nodedata = {}

	-- make some (perlin-) noise ;-)
	local noiseparams = {
	offset = 0.0,
	scale = 1.0,
	spread = vector.new(10, 9, 15),
	seed = 0,
	octaves = 3,
	persistence = 0.5,
	lacunarity = 1.9,
	flags = "defaults",
}	
	local size_v = {
		x = 80,
		y = 80,
		z = 80,
	}
	local perlin_map_object = PerlinNoiseMap(noiseparams, size_v)

local addnodes = function()
	-- get base nodes
	nodedata.c_stone = core.get_content_id("mapgen_stone")
	nodedata.c_snow = core.get_content_id("mapgen_snowblock") or core.get_content_id("mapgen_stone")
	nodedata.c_air = core.get_content_id("air")
	nodedata.c_water = core.get_content_id("mapgen_water_source")	
	nodedata.c_ice = core.get_content_id("mapgen_ice") or core.get_content_id("mapgen_stone")
	nodedata.c_lava = core.get_content_id("mapgen_lava_source")
	-- add ores 
	local orelist = {}
	for _, item in pairs(minetest.registered_ores) do
		if (item.ore_type == "scatter") and (item.y_max >= mountain_above_y) then
			if not((core.get_content_id(item.ore) == nodedata.c_lava) or (core.get_content_id(item.ore) == nodedata.c_water)) then
				if not (string.find(item.ore, "lava") or string.find(item.ore, "water") or string.find(item.ore, "default:mese")) then
					orelist[item.ore] = true
				end
			end
		end
	end
	nodedata.orelist = {}
	local orenr = 0
	for k,v in pairs(orelist) do
		table.insert(nodedata.orelist, core.get_content_id(k))
		orenr = orenr + 1
	end
	nodedata.orenr = orenr
end

core.register_on_mods_loaded(addnodes)


minetest.register_on_generated(function(minp, maxp, seed)
	-- if the chunk does not contain a x ,y & z position the mountain should be at, exit and do nothing.
	
	if ( math.abs(((minp.x + maxp.x) / 2) - mountain_base_x) >= (mountain_base_xdim + 100) ) then
		return
	end	
	if ( math.abs(((minp.z + maxp.z) / 2) - mountain_base_z) >= (mountain_base_zdim + 100) ) then
		return
	end	
	if ( (minp.y > 1000) or (maxp.y < -100) ) then
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

	-- ged ids for blocks
	local c_stone = nodedata.c_stone
	local c_air = nodedata.c_air
	local c_water = nodedata.c_water
	local c_ice = nodedata.c_ice
	local c_snow = nodedata.c_snow

	local perlin_map = perlin_map_object:get_2d_map_flat({x=minp.x, y=minp.z})
	
	-- loop the mapchunk
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				-- vi, voxel indexing object 
				local vi = voxarea:index(x, y, z)
				
				-- calc base height of mointain
				local xw = math.cos(math.abs(x - mountain_base_x)/(math.pi * 200))* 500
				local xh = math.cos(math.abs(x - mountain_base_x)/(math.pi * 100))* 1000				
				local xhi = math.max(xw, xh)
				
				local zhi = math.cos(math.abs(z - mountain_base_z)/(math.pi * 400))
								
				-- get previous height at current test position
				local hm_i = (x - minp.x + 1) + ((z - minp.z) * chunksizeinnodes)	
				local hmh = hmap[hm_i]

				-- get distance from center of mountain
				local dist = math.sqrt(math.pow(x - mountain_base_x, 2) + math.pow((z - mountain_base_z) / 2 , 2))
				
				-- decide new height
				local bh = (xhi * zhi)
				if (hmh > 0) and (hmh < 100) then 
					bh = bh + (hmh / 5)
				end
				
				local h = math.max(bh , hmh)
				
				if (dist < 500) then
					h = h + (perlin_map[hm_i] * 7)
				elseif (dist < 980) then
					h = h + (perlin_map[hm_i] * 3)
				elseif (dist < 1200) then
					h = h + perlin_map[hm_i]
				end
				h = math.floor(h)

				local c_topnode = c_stone
				local c_stonenode = c_stone

				if not (bmap[hm_i] == 0) then
					local topnode = core.registered_biomes[core.get_biome_name(bmap[hm_i])].node_top
					if topnode then
						c_topnode = core.get_content_id(topnode)
						
					end
					local stonenode = core.registered_biomes[core.get_biome_name(bmap[hm_i])].node_stone
					if stonenode then
						c_stonenode = core.get_content_id(stonenode)
					end
				end

				-- set block for mountain				
				if (y == h) then
					if (data[vi] == c_air) or (data[vi] == c_water) then
						if (y > ((perlin_map[hm_i] * 10) + 600)) then
							data[vi] = c_snow
						else
							data[vi] = c_topnode
						end
					end				
				elseif (y < h) then
					if (y > ((perlin_map[hm_i] * 10) + 940)) then
						data[vi] = c_ice
					else
						data[vi] = c_stonenode
					end
				end
			end
		end
	end
	-- sprinkle in some ores from nodedata.orelist
	local ri
	local rimax = chunksizeinnodes * chunksizeinnodes * chunksizeinnodes
	local rore
	for i=1,(256 * mountain_orefactor) do
		ri = math.random(1,rimax)
		if (data[ri] == c_stone) then
			rore = math.random(1, nodedata.orenr)
			data[ri] = nodedata.orelist[rore]
		end
	end
	
	-- write the map data
	voxman_o:set_data(data)
	
	core.generate_ores(voxman_o)
	core.generate_decorations(voxman_o)
	
	
	voxman_o:write_to_map(true)
	
	--print(hmap[1])
	
end)