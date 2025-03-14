
local lfs = require "lfs"
local eqg = require "luaeqg"

local obj = {}

local tonumber = tonumber
local insert = table.insert
local pcall = pcall

local function ReadMTL(path)
	local f = assert(io.open(path, "r"))
	local out = {}
	local cur

	for line in f:lines() do
		local cmd, args = line:match("%s*(%S+)%s([^\n]+)")
		if cmd and args then
			cmd = cmd:lower()
			if cmd == "newmtl" then
				cur = {}
				out[args] = cur
			elseif cmd == "map_kd" then
				cur.diffuse_map = args:match("[%w_]+%.%w+")
			elseif cmd == "map_bump" then
				cur.normal_map = args:match("[%w_]+%.%w+")
			end
		end
	end

	f:close()

	return out
end

function obj.Import(path, dir, appending)
	local f = assert(io.open(path, "r"))

	local materials = {}
	local vertices = {}
	local triangles = {}
	local vert_src = {}
	local uv_src = {}
	local norm_src = {}
	local vert_mem = {}
	local in_object, mat_src
	local mat_index = -1

	local face = function(str)
		local a = vert_mem[str]
		if a then
			return a
		end
		local v, t, n = str:match("(%d+)/(%d*)/(%d+)")
		local vert = vert_src[tonumber(v)]
		local norm = norm_src[tonumber(n)]
		local out = {x = vert.x, y = vert.y, z = vert.z, i = norm.i, j = norm.j, k = norm.k}
		t = tonumber(t)
		if t then
			local tex = uv_src[t]
			out.u = tex.u
			out.v = tex.v
		end
		a = #vertices
		insert(vertices, out)
		vert_mem[str] = a
		return a
	end

	for line in f:lines() do
		local cmd, args = line:match("%s*(%S+)%s([^\n]+)")
		if cmd and args then
			cmd = cmd:lower()
			if mat_src then
				if cmd == "v" then
					local x, y, z = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+) (%-?%d+%.%d+)")
					if x and y and z then
						insert(vert_src, {x = tonumber(x), y = tonumber(y), z = tonumber(z)})
					end
				elseif cmd == "vt" then
					local u, v = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+)")
					if u and v then
						insert(uv_src, {u = tonumber(u), v = tonumber(v)})
					end
				elseif cmd == "vn" then
					local i, j, k = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+) (%-?%d+%.%d+)")
					if i and j and k then
						insert(norm_src, {i = tonumber(i), j = tonumber(j), k = tonumber(k)})
					end
				elseif cmd == "usemtl" then
					local mat = mat_src[args]
					if mat then
						mat_index = mat_index + 1
						local tbl = {name = args, opaque = "Opaque_MaxCBSGE1.fx"}
						if mat.diffuse_map then
							local v = mat.diffuse_map:lower()
							tbl[1] = {name = "e_TextureDiffuse0", type = 2, value = v}
						end
						if mat.normal_map then
							local v = mat.normal_map:lower()
							insert(tbl, {name = "e_TextureNormal0", type = 2, value = v})
						end
						insert(materials, tbl)
					end
				elseif cmd == "f" then
					local v1, v2, v3 = args:match("(%d+/%d*/%d+) (%d+/%d*/%d+) (%d+/%d*/%d+)")
					if v1 and v2 and v3 then
						local a, b, c = face(v1), face(v2), face(v3)
						insert(triangles, {
							[1] = a,
							[2] = b,
							[3] = c,
							group = mat_index,
							flag = 65536,
						})
					end
				end
			elseif cmd == "mtllib" then
				mat_src = ReadMTL(path:gsub("[^\\/]+%.%w+$", args))
			end
		end
	end

	f:close()

	if mat_src then
		local folder = path:match("^.+[\\/]")
		local append_pos = appending and (#dir + 2) or (#dir + 1)
		local load_img = function(name)
			local mat_path = folder .. name
			name = name:lower()
			local pos
			for i, ent in ipairs(dir) do
				if ent.name == name then
					pos = i
					break
				end
			end
			if not pos then
				pos = append_pos
				append_pos = append_pos + 1
			end
			local s, err = pcall(eqg.ImportFlippedImage, mat_path, name, dir, pos)
			if not s then
				error_popup(err)
			end
		end

		for _, mat in pairs(mat_src) do
			local name = mat.diffuse_map
			if name then
				load_img(name)
			end
			name = mat.normal_map
			if name then
				load_img(name)
			end
		end
	end

	return {
		materials = materials,
		vertices = vertices,
		triangles = triangles,
		bones = {},
		bone_assignments = {},
	}
end

function obj.Export(data, path, it)
    log_to_file("obj.Export: Starting export to " .. path)
    local mtl_path = path:sub(1, -4) .. "mtl"
    local f, err = io.open(mtl_path, "w+")
    if not f then
        log_to_file("obj.Export: Failed to open MTL file " .. mtl_path .. ": " .. tostring(err))
        error_popup("Failed to open MTL file: " .. tostring(err))
        return
    end
    log_to_file("obj.Export: Writing MTL to " .. mtl_path)
    f:write("# MTL file produced by EQG Weapon Model Importer\n\n")
    for i, mat in ipairs(data.materials) do
        f:write("newmtl ", mat.name, "\n")
        f:write("d 1.000000\nillum 2\n")
        for j, prop in ipairs(mat) do
            local name = prop.name
            if name == "e_TextureDiffuse0" then
                f:write("map_Kd ", prop.value, "\n")
            elseif name == "e_TextureNormal0" then
                f:write("map_bump ", prop.value, "\n")
            end
        end
        f:write("\n")
    end
    f:close()
    log_to_file("obj.Export: MTL written successfully")

    f, err = io.open(path, "w+")
    if not f then
        log_to_file("obj.Export: Failed to open OBJ file " .. path .. ": " .. tostring(err))
        error_popup("Failed to open OBJ file: " .. tostring(err))
        return
    end
    log_to_file("obj.Export: Writing OBJ to " .. path)
    f:write("# OBJ file produced by EQG Weapon Model Importer\n")
    f:write("mtllib ", it, ".mtl\n")
    
    for _, vert in ipairs(data.vertices) do
        f:write(string.format("v %.6f %.6f %.6f\n", vert.x, vert.y, vert.z))
        f:write(string.format("vt %.6f %.6f\n", vert.u or 0, vert.v or 0))
        f:write(string.format("vn %.6f %.6f %.6f\n", vert.i or 0, vert.j or 0, vert.k or 0))
    end

    local last_group = -1
    for _, tri in ipairs(data.triangles) do
        if tri.group ~= last_group then
            last_group = tri.group
            f:write("usemtl ", data.materials[last_group + 1].name, "\n")
        end
        local v1, v2, v3 = tri[1] + 1, tri[2] + 1, tri[3] + 1
        f:write(string.format("f %d/%d/%d %d/%d/%d %d/%d/%d\n", v1, v1, v1, v2, v2, v2, v3, v3, v3))
    end
    f:close()
    log_to_file("obj.Export: OBJ written successfully")
end

return obj
