local AdminPanel = require 'gui.admin_panel'
local AntigriefPanel = require 'gui.antigrief_panel'
local PROVIDERS = {
    { key = 'admin',     title = { 'fp-admin.panel-title' },           mod = AdminPanel },
    { key = 'antigrief', title = { 'fp-antigrief-panel.panel-title' }, mod = AntigriefPanel },
}
local Public = {}
local function state_of(def)
    local ok, state = pcall(def.get_state)
    return ok and state and true or false
end
function Public.list()
    for _, provider in ipairs(PROVIDERS) do
        for _, def in ipairs(provider.mod.get_toggles()) do
            local labels = def.state_labels or {}
            rcon.print({ '',
                         'TOGGLE\t' .. def.id .. '\t' .. (state_of(def) and '1' or '0') .. '\t',
                         def.caption, '\t',
                         def.tooltip or '', '\t',
                         labels.off or { 'fp-admin.off' }, '\t',
                         labels.on or { 'fp-admin.on' }, '\t' .. provider.key .. '\t',
                         provider.title })
        end
    end
end
local function find_toggle(id)
    for _, provider in ipairs(PROVIDERS) do
        for _, def in ipairs(provider.mod.get_toggles()) do
            if def.id == id then return provider, def end
        end
    end
    return nil
end
function Public.set(id, state)
    local new_state = state == true or state == 'true' or state == 1 or state == '1'
    local provider, def = find_toggle(id)
    if not provider then
        rcon.print('ERR\tunknown toggle: ' .. tostring(id))
        return
    end
    if state_of(def) == new_state then
        rcon.print('no change: ' .. tostring(id) .. ' was already in the requested state (the card was out of date)')
        Public.list()
        return
    end
    local ok, err = provider.mod.set_toggle(id, new_state, nil)
    if not ok then
        rcon.print('ERR\t' .. tostring(err))
        return
    end
    log(string.format('[rcon_toggles] %s/%s requested=%s now=%s (RCON)',
        provider.key, tostring(id), tostring(new_state), tostring(state_of(def))))
    Public.list()
end
return Public
