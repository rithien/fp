local Event = require 'lib.event'
local Constants = require 'constants'
local Session = require 'lib.sessions'
local Jail = require 'lib.jail'
local UG = Constants.untrusted
local de = defines.events
local Public = {}
local blocked_set = {}
for _, name in ipairs(UG.blocked_actions or {}) do
    blocked_set[name] = true
end
local function apply_permissions(group)
    local default = game.permissions.get_group('Default')
    for name, id in pairs(defines.input_action) do
        local allow = true
        if default then allow = default.allows_action(id) end
        if blocked_set[name] then allow = false end
        group.set_allows_action(id, allow)
    end
end
local function apply_new_denies(group)
    if not storage.untrusted_applied_denies then
        storage.untrusted_applied_denies = {}
    end
    local applied = storage.untrusted_applied_denies
    for name in pairs(blocked_set) do
        local id = defines.input_action[name]
        if id and not applied[name] then
            group.set_allows_action(id, false)
            applied[name] = true
        end
    end
end
function Public.ensure_group()
    local group = game.permissions.get_group(UG.group_name)
    if not group then
        group = game.permissions.create_group(UG.group_name)
        if group then apply_permissions(group) end
    end
    if group then apply_new_denies(group) end
    return group
end
local function route(player, trusted_hint)
    if not player or not player.valid then return end
    if Jail.is_jailed(player.name) then return end
    local trusted = player.admin
    if not trusted then
        if trusted_hint ~= nil then
            trusted = trusted_hint
        else
            trusted = Session.get_trusted_player(player)
        end
    end
    local target = trusted and game.permissions.get_group('Default') or Public.ensure_group()
    if target and player.permission_group ~= target then
        target.add_player(player)
    end
end
function Public.refresh_player_group(player)
    route(player, nil)
end
Event.on_init(function() Public.ensure_group() end)
Event.on_configuration_changed(function() Public.ensure_group() end)
Event.add(de.on_player_joined_game, function(event)
    route(game.get_player(event.player_index), nil)
end)
Event.add(Session.events.on_player_trusted, function(event)
    route(game.get_player(event.player_index), true)
end)
Event.add(Session.events.on_player_untrusted, function(event)
    route(game.get_player(event.player_index), false)
end)
Event.add(Session.events.on_trust_refreshed, function(event)
    route(game.get_player(event.player_index), nil)
end)
Event.add(de.on_player_promoted, function(event)
    route(game.get_player(event.player_index), nil)
end)
Event.add(de.on_player_demoted, function(event)
    route(game.get_player(event.player_index), nil)
end)
Jail.set_unjail_group_resolver(function(player) route(player, nil) end)
return Public
