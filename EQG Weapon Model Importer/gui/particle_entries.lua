local eqg = require "luaeqg"
local iup = require "iuplua"

local function log_to_file(msg)
    local f, err = io.open("debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

local list = iup.list{visiblelines = 5, expand = "VERTICAL", visiblecolumns = 6}

local ipairs = ipairs
local edit_button, add_button, remove_button

local data, cur
local function UpdateParticleEntries(prt, name)
    data = prt
    list[1] = nil -- Clear list
    cur = {}
    if not prt or not name then 
        log_to_file("ParticleEntries: Update aborted - prt=" .. tostring(prt) .. ", name=" .. tostring(name))
        return 
    end
    log_to_file("ParticleEntries: Updating for " .. name)
    list.autoredraw = "NO"
    local n = 1
    for _, p in ipairs(prt) do
        if p.particle_name == name then
            list[n] = tostring(n)
            cur[n] = p
            n = n + 1
        end
    end
    list.autoredraw = "YES"
    iup.Redraw(list, 1) -- Force redraw
    log_to_file("ParticleEntries: List updated - items: " .. (list[1] or "nil") .. ", " .. (list[2] or "nil"))
end

local function Edited()
    edit_button.active = "YES"
end

local function EnterKey(self, key)
    if key == iup.K_CR and edit_button.active == "YES" then
        edit_button:action()
    end
end

local field = {
    id = iup.text{visiblecolumns = 12, mask = iup.MASK_UINT, action = Edited, k_any = EnterKey},
    duration = iup.text{visiblecolumns = 12, mask = iup.MASK_UINT, action = Edited, k_any = EnterKey},
    unknown = {},
}

local grid = iup.gridbox{
    iup.label{title = "Particle ID"}, field.id,
    iup.label{title = "Duration?"}, field.duration,
    numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
    gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

for i = 1, 8 do
    local t
    if i == 7 then
        t = iup.text{visiblecolumns = 12, action = Edited, k_any = EnterKey}
    else
        t = iup.text{visiblecolumns = 12, mask = iup.MASK_UINT, action = Edited, k_any = EnterKey}
    end
    field.unknown[i] = t
    iup.Append(grid, iup.label{title = "Unknown".. i})
    iup.Append(grid, t)
end

local particle_selection
function list:action(str, pos, state)
    if state == 1 then
        local p = cur[pos]
        if not p then 
            log_to_file("ParticleEntries: List action aborted - no particle at pos " .. pos)
            return 
        end
        particle_selection = p
        field.id.value = tostring(p.particle_id)
        field.duration.value = tostring(p.duration)
        local u = p.unknown
        for i, v in ipairs(u) do
            if i == 7 then
                field.unknown[7].value = string.format("0x%0.8X", v)
            else
                field.unknown[i].value = tostring(v)
            end
        end
        edit_button.active = "NO"
        iup.Redraw(field.id, 1) -- Force field redraw
        iup.Redraw(field.duration, 1)
        for i = 1, 8 do
            iup.Redraw(field.unknown[i], 1)
        end
        log_to_file("ParticleEntries: Selected particle " .. pos .. " with ID " .. tostring(p.particle_id))
    end
end

local function ClearParticleEntries()
    list[1] = nil
    field.id.value = ""
    field.duration.value = ""
    for _, f in ipairs(field.unknown) do
        f.value = ""
    end
    edit_button.active = "NO"
    particle_selection = nil
    log_to_file("ParticleEntries: Cleared")
end

local function Save()
    local sel = selection
    local dir = open_dir
    local path = open_path
    if not sel or not data or not dir or not path then
        log_to_file("ParticleEntries: Save aborted - missing data")
        return
    end
    local name = sel.name .. ".prt"
    log_to_file("ParticleEntries: Writing particle data for " .. name .. " - data count: " .. #data)
    local s, d = pcall(prt.Write, data, name, eqg.CalcCRC(name))
    if s then
        local pos = sel.prt and sel.prt.pos or (#dir + 1)
        dir[pos] = d
        d.pos = pos
        log_to_file("ParticleEntries: Writing directory to " .. path)
        local s2, d2 = pcall(eqg.WriteDirectory, path, dir)
        if s2 then
            log_to_file("ParticleEntries: Directory written")
            sel.prt = d -- Update sel.prt for consistency
            return true
        else
            log_to_file("ParticleEntries: Directory write failed: " .. tostring(d2))
            error_popup("Failed to write directory: " .. tostring(d2))
        end
    else
        log_to_file("ParticleEntries: Write failed: " .. tostring(d))
        error_popup("Failed to write particle data: " .. tostring(d))
    end
end

add_button = iup.button{title = "Add Particle", padding = "10x0"}
edit_button = iup.button{title = "Commit Changes", padding = "10x0", active = "NO"}
remove_button = iup.button{title = "Remove Particle", padding = "10x0"}

function add_button:action()
    local point = point_selection
    if not point then
        log_to_file("ParticleEntries: Add aborted - no point selected")
        iup.Message("Error", "Please select an emission point first.")
        return
    end
    log_to_file("ParticleEntries: Add Particle clicked")
    local p = {
        particle_id = 0,
        particle_name = point.particle_name,
        duration = 5000,
        unknown = {0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0},
    }
    if not data then
        data = {}
    end
    data[#data + 1] = p
    cur[#cur + 1] = p
    log_to_file("ParticleEntries: Pre-save data count: " .. #data)
    if Save() then
        local sel = selection
        local s, prt_data = pcall(eqg.OpenEntry, sel.prt)
        if s then
            s, prt_data = pcall(prt.Read, sel.prt)
            if s then
                UpdateParticleEntries(prt_data, point.particle_name)
                log_to_file("ParticleEntries: Particle added and data reloaded")
            else
                log_to_file("ParticleEntries: Reload failed after add: " .. tostring(prt_data))
            end
        end
    end
end

function edit_button:action()
    local p = particle_selection
    if not p then return end
    log_to_file("ParticleEntries: Edit clicked")
    p.particle_id = tonumber(field.id.value) or 0
    p.duration = tonumber(field.duration.value) or 0
    for i = 1, 8 do
        if i == 7 then
            p.unknown[i] = tonumber(field.unknown[i].value, 16) or 0xFFFFFFFF
        else
            p.unknown[i] = tonumber(field.unknown[i].value) or 0
        end
    end
    if Save() then
        edit_button.active = "NO"
        local sel = selection
        local s, prt_data = pcall(eqg.OpenEntry, sel.prt)
        if s then
            s, prt_data = pcall(prt.Read, sel.prt)
            if s then
                data = prt_data
                UpdateParticleEntries(data, point_selection.particle_name)
                for i, entry in ipairs(cur) do
                    if entry.particle_id == p.particle_id and entry.particle_name == p.particle_name then
                        list.value = tostring(i)
                        list:action(nil, i, 1)
                        break
                    end
                end
                iup.Refresh(grid)
                log_to_file("ParticleEntries: Entries updated and data reloaded")
            else
                log_to_file("ParticleEntries: Reload failed after edit: " .. tostring(prt_data))
            end
        end
    end
end

function remove_button:action()
    local p = particle_selection
    if not p or not data then
        log_to_file("ParticleEntries: Remove aborted - no particle selected")
        iup.Message("Error", "Please select a particle to remove.")
        return
    end
    log_to_file("ParticleEntries: Removing particle " .. tostring(list.value))
    for i, entry in ipairs(data) do
        if entry == p then
            table.remove(data, i)
            table.remove(cur, tonumber(list.value))
            if Save() then
                local sel = selection
                local s, prt_data = pcall(eqg.OpenEntry, sel.prt)
                if s then
                    s, prt_data = pcall(prt.Read, sel.prt)
                    if s then
                        UpdateParticleEntries(prt_data, point_selection.particle_name)
                        ClearParticleEntries()
                        log_to_file("ParticleEntries: Particle removed and data reloaded")
                    else
                        log_to_file("ParticleEntries: Reload failed after remove: " .. tostring(prt_data))
                    end
                end
            end
            break
        end
    end
end

local dialog = iup.hbox{
    iup.vbox{
        iup.label{title = "Attached Particles"},
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

return {
    dialog = dialog,
    UpdateParticleEntries = UpdateParticleEntries, -- Fixed typo
    ClearParticleEntries = ClearParticleEntries
}