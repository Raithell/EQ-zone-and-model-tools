local eqg = require "luaeqg"
local iup = require "iuplua"

local function log_to_file(msg)
    local f, err = io.open("debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

local list = iup.list{visiblelines = 5, expand = "VERTICAL", visiblecolumns = 16}

local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local edit_button, attach_list, add_button, remove_button

local data, bones
function UpdateParticlePoints(pts, mod)
    data = pts
    list[1] = nil
    attach_list[2] = nil
    if not mod then return end
    local n = 2
    bones = {}
    for i, bone in ipairs(mod.bones) do
        attach_list[n] = bone.name
        bones[i] = bone.name
        n = n + 1
    end
    if not pts then return end
    list.autoredraw = "NO"
    for i, p in ipairs(pts) do
        list[i] = p.particle_name
    end
    list.autoredraw = "YES"
    log_to_file("ParticlePoints: Updated points")
end

local function Edited()
    edit_button.active = "YES"
end

local function EnterKey(self, key)
    if key == iup.K_CR and edit_button.active == "YES" then
        edit_button:action()
    end
end

attach_list = iup.list{visiblecolumns = 10, dropdown = "YES", "ATTACH_TO_ORIGIN",
    action = Edited, k_any = EnterKey, visible_items = 10}

local field = {
    name = iup.text{visiblecolumns = 12, readonly = "YES"},
    trans_x = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    trans_y = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    trans_z = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    rot_x = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    rot_y = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    rot_z = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    scale_x = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    scale_y = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
    scale_z = iup.text{visiblecolumns = 12, mask = iup.MASK_FLOAT, action = Edited, k_any = EnterKey},
}

local grid = iup.gridbox{
    iup.label{title = "Identifier"}, field.name,
    iup.label{title = "Attach To"}, attach_list,
    iup.label{title = "Translation Z"}, field.trans_x,
    iup.label{title = "Translation Y"}, field.trans_y,
    iup.label{title = "Translation X"}, field.trans_z,
    iup.label{title = "Rotation Z"}, field.rot_x,
    iup.label{title = "Rotation Y"}, field.rot_y,
    iup.label{title = "Rotation X"}, field.rot_z,
    iup.label{title = "Scale X"}, field.scale_x,
    iup.label{title = "Scale Y"}, field.scale_y,
    iup.label{title = "Scale Z"}, field.scale_z,
    numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
    gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 2
}

local particle_entries = require "gui/particle_entries"

function list:action(str, pos, state)
    if state == 1 then
        local d = data[pos]
        if not d then return end
        point_selection = d
        field.name.value = d.particle_name
        field.trans_x.value = tostring(d.translation.x)
        field.trans_y.value = tostring(d.translation.y)
        field.trans_z.value = tostring(d.translation.z)
        field.rot_x.value = tostring(d.rotation.x * 45 / 64) -- Convert to user-friendly value
        field.rot_y.value = tostring(d.rotation.y * 45 / 64) -- Convert to user-friendly value
        field.rot_z.value = tostring(d.rotation.z * 45 / 64) -- Convert to user-friendly value
        field.scale_x.value = tostring(d.scale.x)
        field.scale_y.value = tostring(d.scale.y)
        field.scale_z.value = tostring(d.scale.z)

        local name = d.attach_name
        if name == "ATTACH_TO_ORIGIN" then
            attach_list.value = 1
        else
            for i, n in ipairs(bones) do
                if name == n then
                    attach_list.value = i + 1
                    break
                end
            end
        end

        local sel = selection
        if sel.prt then
            local s, prt_data = pcall(eqg.OpenEntry, sel.prt)
            if s then
                s, prt_data = pcall(prt.Read, sel.prt)
                if s then
                    particle_entries.UpdateParticleEntries(prt_data, d.particle_name)
                    log_to_file("ParticlePoints: Updated entries for " .. d.particle_name)
                    return
                end
            end
            error_popup(prt_data)
        else
            particle_entries.UpdateParticleEntries({}, d.particle_name)
            log_to_file("ParticlePoints: No .prt, cleared entries for " .. d.particle_name)
        end
    end
end

function ClearPointFields()
    for _, f in pairs(field) do
        f.value = ""
    end
    edit_button.active = "NO"
    point_selection = nil
    attach_list.value = 0
end

local function SavePoints()
    local sel = selection
    local dir = open_dir
    local path = open_path
    if not sel or not data or not dir or not path then
        log_to_file("ParticlePoints: Save aborted - missing data: sel=" .. tostring(sel) .. ", data=" .. tostring(data) .. ", dir=" .. tostring(dir) .. ", path=" .. tostring(path))
        return
    end
    local name = sel.name .. ".pts"
    log_to_file("ParticlePoints: Writing points for " .. name)
    local s, d = pcall(pts.Write, data, name, eqg.CalcCRC(name))
    if s then
        local pos = sel.pts and sel.pts.pos or (#dir + 1)
        dir[pos] = d
        d.pos = pos
        log_to_file("ParticlePoints: Writing directory to " .. path .. " at pos " .. pos)
        local s2, d2 = pcall(eqg.WriteDirectory, path, dir)
        if s2 then
            log_to_file("ParticlePoints: Directory written")
            sel.pts = d
            return true
        else
            log_to_file("ParticlePoints: Directory write failed: " .. tostring(d2))
            error_popup("Failed to write directory: " .. tostring(d2))
        end
    else
        log_to_file("ParticlePoints: Write failed: " .. tostring(d))
        error_popup("Failed to write points: " .. tostring(d))
    end
end

add_button = iup.button{title = "Add Point", padding = "10x0"}
remove_button = iup.button{title = "Remove Point", padding = "10x0"}

function add_button:action()
    local name
    local input = iup.text{visiblecolumns = 12, nc = 63}
    local getname
    local but = iup.button{title = "Done", action = function() name = tostring(input.value) getname:hide() end}
    getname = iup.dialog{iup.vbox{
        iup.label{title = "Please enter a name to identify the new point:"},
        input, but, gap = 12, nmargin = "15x15", alignment = "ACENTER"},
        k_any = function(self, key) if key == iup.K_CR then but:action() end end}
    iup.Popup(getname)
    iup.Destroy(getname)

    if not name or name:len() < 1 then return end
    log_to_file("ParticlePoints: Adding point " .. name)
    local point = {
        particle_name = name,
        attach_name = "ATTACH_TO_ORIGIN",
        translation = {x = 0, y = 0, z = 0},
        rotation = {x = 0, y = 0, z = 0},
        scale = {x = 1, y = 1, z = 1},
    }
    if not data then
        data = {}
    end
    data[#data + 1] = point
    if SavePoints() then
        UpdateParticlePoints(data, model)
        ClearPointFields()
        log_to_file("ParticlePoints: Point added")
    end
end

edit_button = iup.button{title = "Commit Changes", padding = "10x0", active = "NO"}

function edit_button:action()
    local d = point_selection
    if not d then return end
    log_to_file("ParticlePoints: Edit clicked")
    local v = tonumber(attach_list.value) or 0
    d.attach_name = (v < 2) and "ATTACH_TO_ORIGIN" or bones[v - 1]
    d.translation.x = tonumber(field.trans_x.value) or 0
    d.translation.y = tonumber(field.trans_y.value) or 0
    d.translation.z = tonumber(field.trans_z.value) or 0
    d.rotation.x = (tonumber(field.rot_x.value) or 0) * 64 / 45 -- Convert to stored value
    d.rotation.y = (tonumber(field.rot_y.value) or 0) * 64 / 45 -- Convert to stored value
    d.rotation.z = (tonumber(field.rot_z.value) or 0) * 64 / 45 -- Convert to stored value
    d.scale.x = tonumber(field.scale_x.value) or 1
    d.scale.y = tonumber(field.scale_y.value) or 1
    d.scale.z = tonumber(field.scale_z.value) or 1
    if SavePoints() then
        edit_button.active = "NO"
        local sel = selection
        local s, update = pcall(pts.Read, sel.pts)
        if s then
            data = update
            UpdateParticlePoints(data, model)
            log_to_file("ParticlePoints: Points updated")
        end
    end
end

function remove_button:action()
    local d = point_selection
    if not d or not data then
        log_to_file("ParticlePoints: Remove aborted - no point selected")
        iup.Message("Error", "Please select a point to remove.")
        return
    end
    log_to_file("ParticlePoints: Removing point " .. d.particle_name)
    for i, point in ipairs(data) do
        if point == d then
            table.remove(data, i)
            if SavePoints() then
                UpdateParticlePoints(data, model)
                ClearPointFields()
                log_to_file("ParticlePoints: Point removed")
            end
            break
        end
    end
end

function RefreshPointSelection()
    local d = point_selection
    if not d or not data then return end
    for i, point in ipairs(data) do
        if point == d then
            list:action(d.particle_name, i, 1)
            return
        end
    end
end

return iup.hbox{
    iup.vbox{
        iup.label{title = "Emission Points"},
        list,
        iup.hbox{add_button, remove_button; gap = 5, alignment = "ACENTER"};
        gap = 10, alignment = "ACENTER"
    },
    iup.vbox{
        grid,
        iup.hbox{edit_button; alignment = "ACENTER", gap = 10};
        gap = 10, alignment = "ACENTER"
    };
    gap = 10, alignment = "ACENTER"
}