local Event = require 'lib.event'
local Server = require 'lib.server'
local Constants = require 'constants'
local de = defines.events
local JAIL = Constants.jail
local Public = {}
local allowed_set = {}
for _, name in ipairs(JAIL.allowed_actions or {}) do
    allowed_set[name] = true
end
local unjail_group_resolver = nil
function Public.set_unjail_group_resolver(fn) unjail_group_resolver = fn end
local function ensure_init()
    storage.jailed = storage.jailed or {}
end
Event.on_init(ensure_init)
Event.on_configuration_changed(ensure_init)
local function apply_permissions(group)
    for name, id in pairs(defines.input_action) do
        group.set_allows_action(id, allowed_set[name] and true or false)
    end
end
function Public.ensure_jail_group()
    local group = game.permissions.get_group(JAIL.group_name)
    if not group then
        group = game.permissions.create_group(JAIL.group_name)
        if group then apply_permissions(group) end
    end
    return group
end
local function refresh_jail_group()
    local group = Public.ensure_jail_group()
    if group then apply_permissions(group) end
end
Event.on_init(refresh_jail_group)
Event.on_configuration_changed(refresh_jail_group)
function Public.is_jailed(name)
    if not storage.jailed then return false end
    return storage.jailed[name] and true or false
end
function Public.jail_player(name, reason, source)
    ensure_init()
    if not name or name == '' then return false end
    local transition = not storage.jailed[name]
    storage.jailed[name] = true
    local player = game.get_player(name)
    if player and player.valid then
        local group = Public.ensure_jail_group()
        if group then group.add_player(player) end
    end
    if transition then
        Server.notify_jail_change(name, true, reason)
        game.print({ 'fp-antigrief-panel.bc-jailed', name, source or '' }, { color = { r = 1, g = 1, b = 0 } })
        if player and player.valid then
            player.print({ 'fp-antigrief-panel.jailed-notice' }, { color = { r = 1, g = 0.6, b = 0 } })
        end
    end
    return transition
end
function Public.unjail_player(name)
    ensure_init()
    if not name or name == '' then return false end
    local transition = storage.jailed[name] and true or false
    storage.jailed[name] = nil
    local player = game.get_player(name)
    if player and player.valid then
        if unjail_group_resolver then
            unjail_group_resolver(player)
        else
            local default = game.permissions.get_group('Default')
            if default then default.add_player(player) end
        end
    end
    if transition then
        Server.notify_jail_change(name, false)
        game.print({ 'fp-antigrief-panel.bc-unjailed', name }, { color = { r = 1, g = 1, b = 0 } })
    end
    return transition
end
Event.add(de.on_player_joined_game, function(event)
    ensure_init()
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    if storage.jailed[player.name] then
        local group = Public.ensure_jail_group()
        if group then group.add_player(player) end
    end
end)
return Public
