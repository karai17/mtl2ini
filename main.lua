local love      = _G.love
local files     = {}
local materials = {}

-- Collect list of files
local function get_files(path)
	local items = love.filesystem.getDirectoryItems(path)
	for _, item in ipairs(items) do
		local name, ext = item:match("^(.+)%.(.+)$")
		local filepath  = string.format("%s/%s", path, item)
		local info      = love.filesystem.getInfo(filepath)
		ext = ext and ext:lower() or nil

		if info.type == "file" and ext == "mtl" then
			files[#files+1] = { path=path, name=name, ext=ext, filepath=filepath }
		elseif info.type == "directory" then
			get_files(filepath)
		end
	end
end

-- Parse texture options
local function options(material, map, map_type)
	local u,v,w
	local op = "-o (%d[%d.]*) (%d[%d.]*) (%d[%d.]*) "
	local sp = "-s (%d[%d.]*) (%d[%d.]*) (%d[%d.]*) "
	local tp = "-t (%d[%d.]*) (%d[%d.]*) (%d[%d.]*) "

	u, v, w = map:match(op)
	if u and v and w then
		if w ~= 0 then
			material[string.format("%s_offset_x", map_type)] = u / w
			material[string.format("%s_offset_y", map_type)] = v / w
		else
			material[string.format("%s_offset_x", map_type)] = u
			material[string.format("%s_offset_y", map_type)] = v
		end
	end

	u, v, w = map:match(sp)
	if u and v and w then
		if w ~= 0 then
			material[string.format("%s_scale_x", map_type)] = u / w
			material[string.format("%s_scale_y", map_type)] = v / w
		else
			material[string.format("%s_scale_x", map_type)] = u
			material[string.format("%s_scale_y", map_type)] = v
		end
	end

	u, v, w = map:match(tp)
	if u and v and w then
		if w ~= 0 then
			material[string.format("%s_turbulence_x", map_type)] = u / w
			material[string.format("%s_turbulence_y", map_type)] = v / w
		else
			material[string.format("%s_turbulence_x", map_type)] = u
			material[string.format("%s_turbulence_y", map_type)] = v
		end
	end

	map = map:gsub(op, "")
	map = map:gsub(sp, "")
	map = map:gsub(tp, "")

	material[map_type] = map:gsub([[\\]], "/")

	--[[ TODO: NYI

	-blendu bool
	-blendv bool
	-boost float
	-mm float float
	-texres string?
	-clamp bool
	-bm float
	-imfchan char
	-type

	--]]
end

-- Parse MTL files
local function mtl(file)
	local f = love.filesystem.read(file.filepath)
	for line in f:gmatch("[^\r\n]+") do

		-- Comment
		if line:sub(1,1) == "#" then
			goto continue
		end

		-- New material
		if line:sub(1,7) == "newmtl " then
			local material = {}
			local name = line:match("^newmtl (.+)$")
			material.name = string.gsub(name:lower(), "[^%w%s%-%_%.%#]", "_")
			materials[#materials+1] = material
			goto continue
		end

		-- Simple handle
		local material = materials[#materials]

		--[[ Ambient ]]--

		if line:sub(1,3) == "Ka " then
			local r, g, b = line:match("^Ka (%d[%d.]*) (%d[%d.]*) (%d[%d.]*)$")
			material.ambient_r = r or 0.2
			material.ambient_g = g or 0.2
			material.ambient_b = b or 0.2
			goto continue
		end

		if line:sub(1,7) == "map_Ka " then
			options(material, line:match("^map_Ka (.+)$"), "ambient_map")
			goto continue
		end

		--[[ Diffuse ]]--

		if line:sub(1,3) == "Kd " then
			local r, g, b = line:match("^Kd (%d[%d.]*) (%d[%d.]*) (%d[%d.]*)$")
			material.diffuse_r = r or 0.8
			material.diffuse_g = g or 0.8
			material.diffuse_b = b or 0.8
			goto continue
		end

		if line:sub(1,7) == "map_Kd " then
			options(material, line:match("^map_Kd (.+)$"), "diffuse_map")
			goto continue
		end

		--[[ Specular ]]--

		if line:sub(1,3) == "Ks " then
			local r, g, b = line:match("^Ks (%d[%d.]*) (%d[%d.]*) (%d[%d.]*)$")
			material.specular_r = r or 1.0
			material.specular_g = g or 1.0
			material.specular_b = b or 1.0
			goto continue
		end

		if line:sub(1,7) == "map_Ks " then
			options(material, line:match("^map_Ks (.+)$"), "specular_map")
			goto continue
		end

		if line:sub(1,3) == "Ns " then
			local e = line:match("^Ns (%d[%d.]*)$")
			material.specular_e = e or 0.0
			goto continue
		end

		if line:sub(1,7) == "map_Ns " then
			options(material, line:match("^map_Ns (.+)$"), "specular_e_map")
			goto continue
		end

		--[[ Dissolve ]]--

		if line:sub(1,2) == "d " then
			local a = line:match("^d (%d[%d.]*)$")
			material.dissolve_a = a or 1.0
			goto continue
		end

		if line:sub(1,3) == "Tr " then
			local a = line:match("^Tr (%d[%d.]*)$")
			material.dissolve_a = 1.0 - (a or 1.0)
			goto continue
		end

		if line:sub(1,6) == "map_d " then
			options(material, line:match("^map_d (.+)$"), "dissolve_map")
			goto continue
		end

		--[[ Illumination ]]--

		if line:sub(1,6) == "illum " then
			local i = line:match("^illum (%d+)$")
			material.illumination = i or 1
			goto continue
		end

		--[[ Bump ]]--

		if line:sub(1,9) == "map_bump " then
			options(material, line:match("^map_bump (.+)$"), "bump_map")
			goto continue
		end

		if line:sub(1,5) == "bump " then
			options(material, line:match("^bump (.+)$"), "bump_map")
			goto continue
		end

		--[[ TODO: NYI

		Ke r g b
		Ni n
		sharpness n
		Tf r g b

		disp file.png
		decal file.png
		refl file.png

		--]]

		::continue::
	end
end

-- Generate INI files
local function ini(material)
	local m = { "[material]" }

	--[[ Ambient ]]--

	if material.ambient_r and material.ambient_g and material.ambient_b then
		m[#m+1] = string.format("ambient=%s,%s,%s",
			material.ambient_r,
			material.ambient_g,
			material.ambient_b
		)
	end

	if material.ambient_map then
		m[#m+1] = string.format("ambient_map=%s", material.ambient_map)
	end

	if material.ambient_map_offset_x then
		m[#m+1] = string.format("ambient_map_offset_x=%s", material.ambient_map_offset_x)
	end

	if material.ambient_map_offset_y then
		m[#m+1] = string.format("ambient_map_offset_y=%s", material.ambient_map_offset_y)
	end

	if material.ambient_map_scale_x then
		m[#m+1] = string.format("ambient_map_scale_x=%s", material.ambient_map_scale_x)
	end

	if material.ambient_map_scale_y then
		m[#m+1] = string.format("ambient_map_scale_y=%s", material.ambient_map_scale_y)
	end

	if material.ambient_map_turbulence_x then
		m[#m+1] = string.format("ambient_map_turbulence_x=%s", material.ambient_map_turbulence_x)
	end

	if material.ambient_map_turbulence_y then
		m[#m+1] = string.format("ambient_map_turbulence_y=%s", material.ambient_map_turbulence_y)
	end

	--[[ Diffuse ]]--

	if material.diffuse_r and material.diffuse_g and material.diffuse_b then
		m[#m+1] = string.format("color=%s,%s,%s",
			material.diffuse_r,
			material.diffuse_g,
			material.diffuse_b
		)
	end

	if material.diffuse_map then
		m[#m+1] = string.format("albedo=%s", material.diffuse_map)
	end

	if material.diffuse_map_offset_x then
		m[#m+1] = string.format("albedo_offset_x=%s", material.diffuse_map_offset_x)
	end

	if material.diffuse_map_offset_y then
		m[#m+1] = string.format("albedo_offset_y=%s", material.diffuse_map_offset_y)
	end

	if material.diffuse_map_scale_x then
		m[#m+1] = string.format("albedo_scale_x=%s", material.diffuse_map_scale_x)
	end

	if material.diffuse_map_scale_y then
		m[#m+1] = string.format("albedo_scale_y=%s", material.diffuse_map_scale_y)
	end

	if material.diffuse_map_turbulence_x then
		m[#m+1] = string.format("albedo_turbulence_x=%s", material.diffuse_map_turbulence_x)
	end

	if material.diffuse_map_turbulence_y then
		m[#m+1] = string.format("albedo_turbulence_y=%s", material.diffuse_map_turbulence_y)
	end

	--[[ Specular ]]--

	if material.specular_r and material.specular_g and material.specular_b then
		m[#m+1] = string.format("specular=%s,%s,%s",
			material.specular_r,
			material.specular_g,
			material.specular_b
		)
	end

	if material.specular_map then
		m[#m+1] = string.format("specular_map=%s", material.specular_map)
	end

	if material.specular_map_offset_x then
		m[#m+1] = string.format("specular_map_offset_x=%s", material.specular_map_offset_x)
	end

	if material.specular_map_offset_y then
		m[#m+1] = string.format("specular_map_offset_y=%s", material.specular_map_offset_y)
	end

	if material.specular_map_scale_x then
		m[#m+1] = string.format("specular_map_scale_x=%s", material.specular_map_scale_x)
	end

	if material.specular_map_scale_y then
		m[#m+1] = string.format("specular_map_scale_y=%s", material.specular_map_scale_y)
	end

	if material.specular_map_turbulence_x then
		m[#m+1] = string.format("specular_map_turbulence_x=%s", material.specular_map_turbulence_x)
	end

	if material.specular_map_turbulence_y then
		m[#m+1] = string.format("specular_map_turbulence_y=%s", material.specular_map_turbulence_y)
	end

	if material.specular_e then
		m[#m+1] = string.format("roughness=%s", math.sqrt(2/(material.specular_e+2)))
	end

	if material.specular_e_map then
		m[#m+1] = string.format("roughness_map=%s", material.roughness_map)
	end

	if material.specular_e_map_offset_x then
		m[#m+1] = string.format("roughness_map_offset_x=%s", material.specular_e_map_offset_x)
	end

	if material.specular_e_map_offset_y then
		m[#m+1] = string.format("roughness_map_offset_y=%s", material.specular_e_map_offset_y)
	end

	if material.specular_e_map_scale_x then
		m[#m+1] = string.format("roughness_map_scale_x=%s", material.specular_e_map_scale_x)
	end

	if material.specular_e_map_scale_y then
		m[#m+1] = string.format("roughness_map_scale_y=%s", material.specular_e_map_scale_y)
	end

	if material.specular_e_map_turbulence_x then
		m[#m+1] = string.format("roughness_map_turbulence_x=%s", material.specular_e_map_turbulence_x)
	end

	if material.specular_e_map_turbulence_y then
		m[#m+1] = string.format("roughness_map_turbulence_y=%s", material.specular_e_map_turbulence_y)
	end

	--[[ Dissolve ]]--

	if material.dissolve_a then
		m[#m+1] = string.format("opacity=%s", material.dissolve_a)
	end

	if material.dissolve_map then
		m[#m+1] = string.format("opacity_map=%s", material.dissolve_map)
	end

	if material.dissolve_map_offset_x then
		m[#m+1] = string.format("opacity_map_offset_x=%s", material.dissolve_map_offset_x)
	end

	if material.dissolve_map_offset_y then
		m[#m+1] = string.format("opacity_map_offset_y=%s", material.dissolve_map_offset_y)
	end

	if material.dissolve_map_scale_x then
		m[#m+1] = string.format("opacity_map_scale_x=%s", material.dissolve_map_scale_x)
	end

	if material.dissolve_map_scale_y then
		m[#m+1] = string.format("opacity_map_scale_y=%s", material.dissolve_map_scale_y)
	end

	if material.dissolve_map_turbulence_x then
		m[#m+1] = string.format("opacity_map_turbulence_x=%s", material.dissolve_map_turbulence_x)
	end

	if material.dissolve_map_turbulence_y then
		m[#m+1] = string.format("opacity_map_turbulence_y=%s", material.dissolve_map_turbulence_y)
	end

	--[[ Illumination ]]--

	if material.illumination then
		m[#m+1] = string.format("illumination=%s", material.illumination)
	end

	--[[ Bump ]]--

	if material.bump_map then
		m[#m+1] = string.format("bump_map=%s", material.bump_map)
	end

	if material.bump_map_offset_x then
		m[#m+1] = string.format("bump_map_offset_x=%s", material.bump_map_offset_x)
	end

	if material.bump_map_offset_y then
		m[#m+1] = string.format("bump_map_offset_y=%s", material.bump_map_offset_y)
	end

	if material.bump_map_scale_x then
		m[#m+1] = string.format("bump_map_scale_x=%s", material.bump_map_scale_x)
	end

	if material.bump_map_scale_y then
		m[#m+1] = string.format("bump_map_scale_y=%s", material.bump_map_scale_y)
	end

	if material.bump_map_turbulence_x then
		m[#m+1] = string.format("bump_map_turbulence_x=%s", material.bump_map_turbulence_x)
	end

	if material.bump_map_turbulence_y then
		m[#m+1] = string.format("bump_map_turbulence_y=%s", material.bump_map_turbulence_y)
	end

	--[[ Write to file ]]--

	love.filesystem.write(string.format("materials/%s.ini", material.name), table.concat(m, "\n"))
end

function love.load()
	get_files("data")
	love.filesystem.createDirectory("materials")
	for _, file     in ipairs(files)     do mtl(file)     end
	for _, material in ipairs(materials) do ini(material) end
	love.event.quit()
end
