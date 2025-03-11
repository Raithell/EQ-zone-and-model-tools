local eqg = require "luaeqg"
local ply = require "gui/ply"
local obj = require "gui/obj"
local display = require "gui/display"

local list = iup.list{visiblelines = 10, expand = "VERTICAL", visiblecolumns = 16, sort = "YES"}
local filter = iup.text{visiblecolumns = 15, value = ""}
file_filter = filter

local GatherFiles, FilterFileList

function filter:valuechanged_cb()
    local dir = open_dir
    if dir then
        GatherFiles(dir)
        FilterFileList()
    end
end

local ipairs = ipairs
local pairs = pairs
local pcall = pcall

function GatherFiles(dir)
    for i, ent in ipairs(dir) do
        local name, ext = ent.name:match("^(%w+)%.(%a%a%a)$")
        if name and (ext == "mod" or ext == "pts" or ext == "prt") then
            local bn = by_name[name]
            if not bn then
                ent.pos = i
                by_name[name] = {[ext] = ent, name = name}
            elseif not bn[ext] then
                ent.pos = i
                bn[ext] = ent
            end
        end
    end
end

function UpdateFileList(path, silent)
    log_to_file("FileList: UpdateFileList started for " .. path)
    selection = nil
    if open_dir then
        log_to_file("FileList: Resetting open_dir without closing")
        open_dir = nil -- Avoid CloseDirectory mid-session
    else
        log_to_file("FileList: No open directory to reset")
    end
    open_path = path
    log_to_file("FileList: Loading directory " .. path)
    local dir = eqg.LoadDirectory(path)
    open_dir = dir
    by_name = {}
    log_to_file("FileList: Gathering files")
    GatherFiles(dir)
    if not silent then
        log_to_file("FileList: Filtering list")
        FilterFileList()
    end
    log_to_file("FileList: UpdateFileList completed")
end

function FilterFileList()
    list[1] = nil
    list.autoredraw = "NO"
    local f = filter.value
    local n = 1
    if f:len() > 0 then
        f = f:gsub("%.", "%%%."):lower()
        if f:find("%%", -1) then f = f .. "%" end
        for name, tbl in pairs(by_name) do
            if name:lower():find(f) and tbl.mod then
                list[n] = name
                n = n + 1
            end
        end
    else
        for name, tbl in pairs(by_name) do
            if tbl.mod then
                list[n] = name
                n = n + 1
            end
        end
    end
    list.autoredraw = "YES"
    list.topitem = "1"
end

function RefreshSelection()
    local sel = selection
    local path = open_path
    if not sel or not path then 
        log_to_file("FileList: RefreshSelection aborted - missing sel or path")
        return 
    end
    log_to_file("FileList: Updating file list for refresh")
    UpdateFileList(path, true)
    selection = by_name[sel.name]
    log_to_file("FileList: Selection refreshed")
end

function list:action(str, pos, state)
    if state == 1 then
        log_to_file("FileList: Model selected: " .. str)
        local sel = by_name[str]
        if selection ~= sel then
            selection = sel
            local data = eqg.OpenEntry(sel.mod)
            data = mod.Read(sel.mod)
            model = data
            ClearDisplay()
            UpdateDisplay(data, str, sel)
            log_to_file("FileList: Display updated for " .. str)
        end
    end
end

function SaveDirEntry(entry, name)
    local dir = open_dir
    if not dir or not open_path then return end
    for i, ent in ipairs(dir) do
        if ent.name == name then
            dir[i] = entry
            eqg.WriteDirectory(open_path, dir)
            UpdateFileList(open_path, true)
            return
        end
    end
end

function Export()
    local dlg = iup.filedlg{title = "Export to...", dialogtype = "DIR"}
    iup.Popup(dlg)
    if dlg.status == "0" then
        local path = dlg.value
        local val = list.value
        if path and val then
            local str = list[list.value]
            local outpath = path .."\\".. str .. ".ply"
            local data = by_name[str].mod
            local entry = eqg.OpenEntry(data)
            data = mod.Read(entry)
            ply.Export(data, outpath)
            local msg = iup.messagedlg{title = "Export Status", value = "Export to ".. outpath .." complete."}
            iup.Popup(msg)
            iup.Destroy(msg)
            iup.Destroy(dlg)
        end
    end
    iup.Destroy(dlg)
end

function Import(filter, import_func)
    local dlg = iup.filedlg{title = "Select file to import", dialogtype = "FILE", extfilter = filter}
    iup.Popup(dlg)
    if dlg.status == "0" then
        local path = dlg.value
        local dir = open_dir
        if path and dir then
            local id = 1000
            local input = iup.text{visiblecolumns = 12, mask = iup.MASK_UINT}
            local getid
            local but = iup.button{title = "Done", action = function() id = tonumber(input.value) or 1000 getid:hide() end}
            getid = iup.dialog{iup.vbox{
                iup.label{title = "Please enter an ID number for the incoming weapon model:"},
                input, but, gap = 12, nmargin = "15x15", alignment = "ACENTER"},
                k_any = function(self, key) if key == iup.K_CR then but:action() end end}
            iup.Popup(getid)
            iup.Destroy(getid)
            local name = "it".. id
            local pos = by_name[name]
            local overwrite = false
            if pos then
                pos = pos.mod.pos
                local warn = iup.messagedlg{title = "Overwrite?",
                    value = "A model with ID ".. id .." already exists in this archive. Overwrite it?",
                    buttons = "YESNO", dialogtype = "WARNING"}
                iup.Popup(warn)
                overwrite = (warn.buttonresponse == "1")
                iup.Destroy(warn)
                if not overwrite then return end
            else
                pos = #dir + 1
            end
            log_to_file("FileList: Importing " .. path .. " as " .. name)
            local data = import_func(path, dir, (pos > #dir))
            name = name .. ".mod"
            log_to_file("FileList: Writing model " .. name)
            local entry = mod.Write(data, name, eqg.CalcCRC(name))
            log_to_file("FileList: Model written, updating directory at pos " .. pos)
            dir[pos] = entry
            log_to_file("FileList: Writing directory")
            eqg.WriteDirectory(open_path, dir)
            log_to_file("FileList: Directory updated successfully")
            local msg = iup.messagedlg{title = "Import Status", value = "Import of ".. name .." complete."}
            iup.Popup(msg)
            log_to_file("FileList: Pre-UpdateFileList for " .. open_path)
            UpdateFileList(open_path)
            log_to_file("FileList: Post-UpdateFileList")
            iup.Destroy(msg)
            iup.Destroy(dlg)
            return
        end
    end
    iup.Destroy(dlg)
end

local function ImportPLY()
    Import("Stanford PLY (*.ply)|*.ply|", ply.Import)
end

local function ImportOBJ()
    Import("Wavefront OBJ (*.obj)|*.obj|", obj.Import)
end

function list:button_cb(button, pressed, x, y)
    if button == iup.BUTTON3 and pressed == 0 then
        local has = selection and "YES" or "NO"
        local mx, my = iup.GetGlobal("CURSORPOS"):match("(%d+)x(%d+)")
        local menu = iup.menu{
            iup.submenu{title = "Export Model", active = has,
                iup.menu{
                    iup.item{title = "To .ply", action = Export},
                }
            },
            iup.submenu{title = "Import Model",
                iup.menu{
                    iup.item{title = "From .obj", action = ImportOBJ},
                    iup.item{title = "From .ply", action = ImportPLY},
                }
            }
        }
        iup.Popup(menu, mx, my)
        iup.Destroy(menu)
    end
end

return iup.vbox{iup.hbox{iup.label{title = "Filter"}, filter; alignment = "ACENTER", gap = 5}, list;
    alignment = "ACENTER", gap = 5}