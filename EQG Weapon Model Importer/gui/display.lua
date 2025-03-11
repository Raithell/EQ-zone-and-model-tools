local eqg = require "luaeqg"
local iup = require "iuplua"
local property = require "gui/property"
local particle_button = require "gui/particle"


local function log_to_file(msg)
    local f, err = io.open("debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

function ClearDebugLog()
    local f, err = io.open("debug.log", "w")
    if f then
        f:close()
        log_to_file("Debug log cleared")
    end
end

local edit_button
local cur_data, cur_name, cur_material, cur_property, cur_name_mod

local function Edited()
    edit_button.active = "YES"
end

local function EnterKey(self, key)
    if key == iup.K_CR and edit_button.active == "YES" then
        edit_button:action()
    end
end

local field = {
    name = iup.text{visiblecolumns = 12, readonly = "YES"},
    vert_count = iup.text{visiblecolumns = 12, readonly = "YES"},
    tri_count = iup.text{visiblecolumns = 12, readonly = "YES"},
    has_particles = iup.text{visiblecolumns = 12, readonly = "YES"},
    material_opaque = iup.text{visiblecolumns = 12, action = Edited, k_any = EnterKey},
    property_name = iup.text{visiblecolumns = 12, readonly = "YES"},
    property_type = iup.text{visiblecolumns = 12, readonly = "YES"},
    property_value = iup.text{visiblecolumns = 12, action = Edited, k_any = EnterKey},
}

local stats_grid = iup.gridbox{
    iup.label{title = "Name"}, field.name,
    iup.label{title = "Num Vertices"}, field.vert_count,
    iup.label{title = "Num Triangles"}, field.tri_count,
    iup.label{title = "Particles"}, field.has_particles,
    numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
    gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 2
}

local material_list = iup.list{visiblelines = 5, expand = "VERTICAL", visiblecolumns = 16}
local property_list = iup.list{visiblelines = 5, expand = "VERTICAL", visiblecolumns = 16}
local add_button = property(material_list, property_list, function() return cur_data end)  -- Closure for cur_data

local ipairs = ipairs

local UpdateViewer

function UpdateDisplay(d, str, set)
	ClearDebugLog()
    cur_data = d
    cur_name = str
    cur_name_mod = str .. ".mod"
    set = set or by_name[str]

    field.name.value = str
    field.vert_count.value = #d.vertices
    field.tri_count.value = #d.triangles
    field.has_particles.value = (set.prt and set.pts) and "Yes" or "No"

    material_list[1] = nil
    material_list.autoredraw = "NO"
    for i, mat in ipairs(d.materials) do
        material_list[i] = mat.name
    end
    material_list.autoredraw = "YES"

    property_list[1] = nil

    UpdateViewer(d)
end

local function FindTexture(name)
    local dir = open_dir
    if dir then
        name = name:lower()
        for i, ent in ipairs(dir) do
            if ent.name == name then
                local s, err = pcall(eqg.OpenEntry, ent)
                if s then
                    ent.png_name = ent.name:match("[^%.]+") .. ".png"
                    return ent
                end
                return
            end
        end
    end
end

local function FindDiffuse(m)
    for i, mat in ipairs(m) do
        for j, prop in ipairs(mat) do
            if prop.name == "e_TextureDiffuse0" then
                return FindTexture(prop.value)
            end
        end
    end
end

function UpdateViewer(d)
    local v = d.vertices
    local t = d.triangles
    local m = d.materials

    local texture = FindDiffuse(m)
    local s, err = pcall(viewer.LoadModel, v, t, texture, texture and (texture.name:match("%.(%w+)$") == "dds"))
    if not s then
        error_popup(err)
    end
end

local properties_grid = iup.gridbox{
    iup.label{title = "Material Opaque"}, field.material_opaque,
    iup.label{title = "Property Name"}, field.property_name,
    iup.label{title = "Property Type"}, field.property_type,
    iup.label{title = "Property Value"}, field.property_value,
    numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
    gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

function material_list:action(str, pos, state)
    if state == 1 and cur_data then
        local m = cur_data.materials[pos]
        cur_material = m
        log_to_file("Display: Material selected - pos: " .. pos .. ", name: " .. (m.name or "nil"))
        property_list[1] = nil
        property_list.autoredraw = "NO"
        for i, p in ipairs(m) do
            property_list[i] = p.name
        end
        property_list.autoredraw = "YES"

        field.material_opaque.value = m.opaque
        field.property_name.value = ""
        field.property_type.value = ""
        field.property_value.value = ""
        edit_button.active = "NO"
    end
end

function property_list:action(str, pos, state)
    if state == 1 and cur_data and cur_material then
        local p = cur_material[pos]
        cur_property = p
        log_to_file("Display: Property selected - pos: " .. pos .. ", name: " .. (p and p.name or "nil"))
        field.property_name.value = p.name
        field.property_type.value = p.type
        field.property_value.value = p.value
        if p.type == 0 then
            field.property_value.mask = iup.MASK_FLOAT
        else
            field.property_value.mask = nil
        end
    end
end

edit_button = iup.button{title = "Commit Change", padding = "22x0", active = "NO"}

local function SaveDirEntry(dir_entry, name)
    local sel = selection
    local dir = open_dir
    local path = open_path
    if not sel or not dir or not path then 
        log_to_file("Display: SaveDirEntry aborted - missing data")
        return 
    end
    local pos = sel.mod and sel.mod.pos or (#dir + 1)
    dir[pos] = dir_entry
    dir_entry.pos = pos
    log_to_file("Display: Writing directory to " .. path)
    open_dir = nil -- Prevent crash in UpdateFileList
    local s, d = pcall(eqg.WriteDirectory, path, dir)
    if s then
        log_to_file("Display: Directory written successfully")
        open_dir = dir -- Update in-memory state
        selection.mod = dir[pos] -- Sync selection
        return true
    else
        error_popup("Failed to write directory: " .. tostring(d))
        return false
    end
end

function edit_button:action()
    if not cur_data or not cur_material or not cur_property or not cur_name then return end
    log_to_file("Display: Edit button clicked")
    local d = cur_data
    local m = cur_material
    local p = cur_property

    m.opaque = field.material_opaque.value
    if p.type == 0 then
        p.value = tonumber(field.property_value.value) or 0
    else
        p.value = field.property_value.value
    end

    log_to_file("Display: Saving changes")
    local s, dir_entry = pcall(mod.Write, d, cur_name_mod, eqg.CalcCRC(cur_name_mod))
    if s then
        local s2 = SaveDirEntry(dir_entry, cur_name_mod)
        if s2 then
            self.active = "NO"
            log_to_file("Display: Changes saved successfully")
            UpdateDisplay(cur_data, cur_name, selection) -- Refresh UI with updated data
        else
            error_popup("Failed to save directory entry")
        end
    else
        error_popup("Failed to write model: " .. dir_entry)
    end
end

function SaveNewProperty()
    local d = cur_data
    local name = cur_name_mod
    if not d or not name then return end

    UpdateDisplay(d, cur_name, selection)
    material_list:action(nil, 1, 1)

    local s, dir_entry = pcall(mod.Write, d, name, eqg.CalcCRC(name))
    if s then
        SaveDirEntry(dir_entry, name)
    else
        error_popup(dir_entry)
    end
end

function ClearDisplay()
    for _, f in pairs(field) do
        f.value = ""
    end
    material_list[1] = nil
    property_list[1] = nil
    cur_data = nil
    cur_material = nil
    edit_button.active = "NO"
end

return iup.hbox{
    iup.vbox{
        stats_grid,
        iup.vbox{
            iup.label{title = "Materials"},
            material_list;
            gap = 10, alignment = "ACENTER"
        };
        gap = 15, alignment = "ACENTER"
    },
    iup.vbox{
        properties_grid,
        iup.vbox{
            iup.label{title = "Material Properties"},
            property_list,
            iup.hbox{
                iup.vbox{
                    add_button, -- Now a vbox with Add and Remove Property
                    gap = 5, alignment = "ACENTER"
                },
                iup.vbox{
                    particle_button,
                    edit_button;
                    gap = 5, alignment = "ACENTER"
                };
                gap = 10, alignment = "ACENTER"
            };
            gap = 10, alignment = "ACENTER"
        };
        gap = 15, alignment = "ACENTER"
    };
    gap = 10
}