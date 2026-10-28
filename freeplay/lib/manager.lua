local Event = require 'lib.event'
local Server = require 'lib.server'
local DebugLog = require 'lib.debug_log'
local Public = {}
Public.events = {
    on_manager_changed = Event.generate_event_name('on_manager_changed'),
}
local color_yellow = { r = 1, g = 1, b = 0 }
local function ensure_init()
    storage.managers = storage.managers or {}
end
Event.on_init(ensure_init)
Event.on_configuration_changed(ensure_init)
local function name_of(player_or_name)
    if type(player_or_name) == 'string' then return player_or_name end
    if type(player_or_name) == 'table' or type(player_or_name) == 'userdata' then
        local ok, name = pcall(function() return player_or_name.name end)
        if ok and type(name) == 'string' then return name end
    end
    return nil
end
function Public.is_manager(player_or_name)
    local name = name_of(player_or_name)
    if not name then return false end
    local m = storage.managers
    return m ~= nil and m[name] == true
end
function Public.is_staff(player)
    if not player or not player.valid then return false end
    if player.admin then return true end
    return Public.is_manager(player.name)
end
local function set_state(name, on)
    ensure_init()
    local current = storage.managers[name] == true
    if current == on then return false end
    storage.managers[name] = on and true or nil
    local player = game.get_player(name)
    if player and player.valid then
        Event.raise(Public.events.on_manager_changed, { player_index = player.index, manager = on })
    end
    return true
end
function Public.set_manager(name, on, source)
    if type(name) ~= 'string' or name == '' then return false end
    on = on and true or false
    if not set_state(name, on) then return false end
    Server.notify_manager_change(name, on, source)
    game.print({ on and 'fp-antigrief-panel.bc-manager-granted' or 'fp-antigrief-panel.bc-manager-revoked',
                 name, source or '' }, { color = color_yellow })
    return true
end
function Public.apply_remote(name, on)
    if type(name) ~= 'string' or name == '' then return false end
    on = on and true or false
    local changed = set_state(name, on)
    if changed then
        DebugLog.log('[manager] remote %s: %s', on and 'grant' or 'revoke', name)
    end
    return changed
end
return Public
