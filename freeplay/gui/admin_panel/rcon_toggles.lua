local AdminPanel = require 'gui.admin_panel'
local Public = {}
local function state_of(def)
    local ok, state = pcall(def.get_state)
    return ok and state and true or false
end
function Public.list()
    for _, def in ipairs(AdminPanel.get_toggles()) do
        rcon.print({ '', 'TOGGLE\t', def.id, '\t', state_of(def) and '1' or '0', '\t',
                     def.caption, '\t', def.tooltip or '' })
    end
end
function Public.set(id, state)
    local new_state = state == true or state == 'true' or state == 1 or state == '1'
    local ok, err = AdminPanel.set_toggle(id, new_state, nil)
    if not ok then
        rcon.print('ERR\t' .. tostring(err))
        return
    end
    log(string.format('[admin_panel] toggle %s -> %s (RCON)', tostring(id), tostring(new_state)))
    Public.list()
end
return Public
