local function log_to_file(msg)
    local f, err = io.open("debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

return function(material_list, property_list, cur_data_ref)  -- cur_data_ref is a function
    local button = iup.button{title = "Add Property", padding = "20x0"}
    local remove_button = iup.button{title = "Remove Property", padding = "20x0"}

    local options = {
        e_TextureDiffuse0 = 2,
        e_TextureNormal0 = 2,
        e_TextureCoverage0 = 2,
        e_TextureEnvironment0 = 2,
        e_TextureGlow0 = 2,
        e_fShininess0 = 0,
        e_fBumpiness0 = 0,
        e_fEnvMapStrength0 = 0,
    }

    function button:action()
        local mat_pos = tonumber(material_list.value) or 0
        if mat_pos == 0 or not cur_data_ref() then return end  -- Call cur_data_ref()
        local m = cur_data_ref().materials[mat_pos]  -- Call cur_data_ref()
        if not m then return end
        local list = iup.list{dropdown = "YES", visiblecolumns = 16}
        local opt = {}
        for o in pairs(options) do
            opt[o] = true
        end
        for _, p in ipairs(m) do
            opt[p.name] = nil
        end

        local n = 1
        for o in pairs(opt) do
            list[n] = o
            n = n + 1
        end

        local dlg
        local but = iup.button{title = "Add", action = function() dlg:hide() end}
        local cancel = iup.button{title = "Cancel", action = function() list.value = -1 dlg:hide() end}
        dlg = iup.dialog{iup.vbox{
            iup.label{title = "Select a property to add:"},
            list, iup.hbox{but, cancel; gap = 10, alignment = "ACENTER"},
            gap = 12, nmargin = "15x15", alignment = "ACENTER"}}
        iup.Popup(dlg)

        if list.value ~= -1 then
            local str = list[list.value]
            local t = options[str]
            table.insert(m, {name = str, type = t, value = (t == 0) and 0 or ""})
            SaveNewProperty()
            property_list[1] = nil
            property_list.autoredraw = "NO"
            for i, p in ipairs(m) do
                property_list[i] = p.name
            end
            property_list.autoredraw = "YES"
            property_list.value = #m
            property_list:action(property_list[#m], #m, 1)
        end

        iup.Destroy(dlg)
    end

    function remove_button:action()
        local mat_pos = tonumber(material_list.value) or 0
        local prop_pos = tonumber(property_list.value) or 0
        log_to_file("Property: Remove attempt - material_list.value: " .. mat_pos .. ", property_list.value: " .. prop_pos .. ", cur_data: " .. (cur_data_ref() and "set" or "nil"))  -- Call cur_data_ref()
        if not cur_data_ref() or mat_pos == 0 then  -- Call cur_data_ref()
            log_to_file("Property: Remove aborted - no material selected")
            iup.Message("Error", "Please select a material first.")
            return
        end
        local m = cur_data_ref().materials[mat_pos]  -- Call cur_data_ref()
        if not m or prop_pos == 0 then
            log_to_file("Property: Remove aborted - no property selected")
            iup.Message("Error", "Please select a property to remove.")
            return
        end
        local p = m[prop_pos]
        if not p then
            log_to_file("Property: Remove aborted - invalid property index")
            iup.Message("Error", "Invalid property selected.")
            return
        end
        log_to_file("Property: Removing property " .. p.name)
        table.remove(m, prop_pos)
        SaveNewProperty()
        property_list[1] = nil
        property_list.autoredraw = "NO"
        for i, prop in ipairs(m) do
            property_list[i] = prop.name
        end
        property_list.autoredraw = "YES"
        if #m > 0 then
            property_list.value = 1
            property_list:action(property_list[1], 1, 1)
        else
            field.property_name.value = ""
            field.property_type.value = ""
            field.property_value.value = ""
        end
        log_to_file("Property: Property removed successfully")
    end

    return iup.vbox{
        button,
        remove_button;
        gap = 5, alignment = "ACENTER"
    }
end