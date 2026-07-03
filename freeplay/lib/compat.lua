local Compat = {}
local base_version = (script and script.active_mods and script.active_mods.base) or '0.0.0'
local major, minor = base_version:match('^(%d+)%.(%d+)')
major = tonumber(major) or 0
minor = tonumber(minor) or 0
local is_21 = major > 2 or (major == 2 and minor >= 1)
Compat.new_fluid_api = is_21
Compat.crafter_inventory = is_21
Compat.main_inventory_indices = is_21
    and { defines.inventory.chest, defines.inventory.crafter_input, defines.inventory.crafter_output }
    or  { defines.inventory.chest, defines.inventory.furnace_source, defines.inventory.furnace_result,
          defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output }
local function proto_of(e)
    return (e.type == 'entity-ghost') and e.ghost_prototype or e.prototype
end
function Compat.fluidbox_count(e)
    return #proto_of(e).fluidbox_prototypes
end
function Compat.has_fluidboxes(e)
    return #proto_of(e).fluidbox_prototypes > 0
end
function Compat.fluidbox_prototype(e, i)
    return proto_of(e).fluidbox_prototypes[i]
end
if Compat.new_fluid_api then
    function Compat.fluid_at(e, i)
        local fl
        local ok = pcall(function() fl = e.get_fluid(i) end)
        return ok and fl or nil
    end
    function Compat.fluid_name_at(e, i)
        local name
        local ok = pcall(function()
            local filt = e.get_fluid_filter(i)
            if filt and filt.fluid then
                local f = filt.fluid
                name = type(f) == 'string' and f or f.name
            else
                local fl = e.get_fluid(i)
                name = fl and fl.name
            end
        end)
        return ok and name or nil
    end
    function Compat.pipe_connections(e, i)
        local conns
        local ok = pcall(function() conns = e.get_fluid_box_pipe_connections(i) end)
        return (ok and conns) or {}
    end
else
    function Compat.fluid_at(e, i)
        local fl
        local ok = pcall(function() fl = e.fluidbox[i] end)
        return ok and fl or nil
    end
    function Compat.fluid_name_at(e, i)
        local name
        local ok = pcall(function()
            local fb = e.fluidbox
            local filt = fb.get_filter(i)
            if filt then
                name = filt.name
            else
                local fl = fb[i]
                name = fl and fl.name
            end
        end)
        return ok and name or nil
    end
    function Compat.pipe_connections(e, i)
        local conns
        local ok = pcall(function() conns = e.fluidbox.get_pipe_connections(i) end)
        return (ok and conns) or {}
    end
end
return Compat
