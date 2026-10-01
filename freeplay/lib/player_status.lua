local Event = require 'lib.event'
local Token = require 'lib.token'
local Server = require 'lib.server'
local Sessions = require 'lib.sessions'
local Jail = require 'lib.jail'
local DebugLog = require 'lib.debug_log'
local Constants = require 'constants'
local DATA_SET = 'player_status'
local Public = { DATA_SET = DATA_SET }
local function non_empty(s)
    return type(s) == 'string' and s ~= '' and s or nil
end
function Public.apply(name, state)
    if type(name) ~= 'string' or name == '' or type(state) ~= 'table' then return end
    local player = game.get_player(name)
    DebugLog.log('[player_status] apply %s: banned=%s admin=%s jailed=%s trusted=%s known=%s',
        name, tostring(state.banned), tostring(state.admin), tostring(state.jailed),
        tostring(state.trusted), tostring(player ~= nil))
    if state.banned then
        if player and player.valid then
            game.ban_player(player, non_empty(state.ban_reason) or Constants.audit.global_ban)
        end
        return
    end
    if state.admin and player and player.valid and not player.admin then
        player.admin = true
    end
    if state.jailed and not Jail.is_jailed(name) then
        Jail.jail_player(name,
            non_empty(state.jail_reason) or string.format(Constants.audit.jailed_by, 'clusterio'),
            'clusterio')
    end
    if state.trusted then
        Sessions.apply_remote_trust(name)
    else
        Sessions.apply_remote_untrust(name)
    end
end
local fetch_token = Token.register(function(data)
    Public.apply(data.key, data.value)
end)
function Public.request(name)
    Server.try_get_data(DATA_SET, tostring(name), fetch_token)
end
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    Public.request(player.name)
end)
Server.on_data_set_changed(DATA_SET, function(data)
    Public.apply(data.key, data.value)
end)
return Public
