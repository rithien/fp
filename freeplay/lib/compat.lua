local Compat = {}
local is_21 = defines.inventory.crafter_input ~= nil
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
        return e.get_fluid(i)
    end
    function Compat.fluid_name_at(e, i)
        local filt = e.get_fluid_filter(i)
        if filt and filt.fluid then
            local f = filt.fluid
            return type(f) == 'string' and f or f.name
        end
        local fl = e.get_fluid(i)
        return fl and fl.name
    end
    function Compat.pipe_connections(e, i)
        return e.get_fluid_box_pipe_connections(i) or {}
    end
else
    function Compat.fluid_at(e, i)
        return e.fluidbox[i]
    end
    function Compat.fluid_name_at(e, i)
        local fb = e.fluidbox
        local filt = fb.get_filter(i)
        if filt then return filt.name end
        local fl = fb[i]
        return fl and fl.name
    end
    function Compat.pipe_connections(e, i)
        return e.fluidbox.get_pipe_connections(i) or {}
    end
end
return Compat
