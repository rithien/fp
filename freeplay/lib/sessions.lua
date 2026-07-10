local Event = require 'lib.event'
local Token = require 'lib.token'
local Task = require 'lib.task'
local Server = require 'lib.server'
local Constants = require 'constants'
local set_timeout_in_ticks = Task.set_timeout_in_ticks
local set_data = Server.set_data
local try_get_data = Server.try_get_data
local session_data_set = 'sessions'
local manually_untrusted_data_set = 'manually_untrusted'
local settings = Constants.sessions
local UPLOAD_INFLIGHT_TTL_TICKS = 60 * 60
local Public = {}
Public.events = {
    on_player_trusted = Event.generate_event_name('on_player_trusted'),
    on_player_untrusted = Event.generate_event_name('on_player_untrusted'),
    on_trust_refreshed = Event.generate_event_name('on_trust_refreshed')
}
local function notify_trust_refreshed(player_name)
    local player = game.get_player(player_name)
    if player and player.valid then
        Event.raise(Public.events.on_trust_refreshed, { player_index = player.index })
    end
end
local function ensure_init()
    storage.sessions = storage.sessions or {}
    storage.online_track = storage.online_track or {}
    storage.trusted = storage.trusted or {}
    storage.manually_untrusted = storage.manually_untrusted or {}
    storage.sessions_upload_inflight = storage.sessions_upload_inflight or {}
    storage.sessions_sticky_resolved = storage.sessions_sticky_resolved or {}
end
Event.on_init(ensure_init)
Event.on_configuration_changed(ensure_init)
function Public.get_trusted_threshold()
    return storage.sessions_threshold_override or settings.trusted_value
end
function Public.set_trusted_threshold(ticks)
    if not ticks or ticks <= 0 then
        storage.sessions_threshold_override = nil
        return settings.trusted_value
    end
    storage.sessions_threshold_override = ticks
    return ticks
end
local function get_min_save_time()
    local threshold = Public.get_trusted_threshold()
    if settings.required_only_time_to_save_time < threshold then
        return settings.required_only_time_to_save_time
    end
    return threshold
end
local try_download_data_token = Token.register(function(data)
    ensure_init()
    local player_name = data.key
    local value = data.value
    local threshold = Public.get_trusted_threshold()
    if value then
        storage.sessions[player_name] = value
        if value > threshold and not storage.manually_untrusted[player_name] then
            if storage.sessions_sticky_resolved[player_name] then
                storage.trusted[player_name] = true
            else
                Public.try_dl_manually_untrusted(player_name)
            end
        end
    else
        local player = game.get_player(player_name)
        if not player or not player.valid then return end
        if player.online_time > threshold and not storage.manually_untrusted[player_name] then
            storage.sessions[player_name] = player.online_time
            if storage.sessions_sticky_resolved[player_name] then 
                storage.trusted[player_name] = true
            else
                Public.try_dl_manually_untrusted(player_name)
            end
            set_data(session_data_set, player_name, player.online_time)
        else
            storage.sessions[player_name] = 0
            if player.online_time >= get_min_save_time() then
                set_data(session_data_set, player_name, storage.sessions[player_name])
            end
        end
    end
    notify_trust_refreshed(player_name)
end)
local try_download_manually_untrusted_token = Token.register(function(data)
    ensure_init()
    local player_name = data.key
    storage.sessions_sticky_resolved[player_name] = true
    if data.value then
        storage.manually_untrusted[player_name] = true
        if storage.trusted[player_name] then
            storage.trusted[player_name] = nil 
        end
    end
    Public.try_dl_data(player_name) 
end)
local try_upload_data_token = Token.register(function(data)
    ensure_init()
    local player_name = data.key
    if not player_name then return end
    storage.sessions_upload_inflight[player_name] = nil 
    local player = game.get_player(player_name)
    if not player or not player.valid then return end
    if player.online_time <= get_min_save_time() then
        return
    end
    local old_time_ingame = data.value or 0
    if not storage.online_track[player_name] then
        storage.online_track[player_name] = 0
    end
    if storage.online_track[player_name] > player.online_time then
        storage.online_track[player_name] = 0
        return
    end
    local new_time = old_time_ingame + player.online_time - storage.online_track[player_name]
    if new_time <= 0 then
        log('[sessions] ' .. player_name .. ' computed non-positive delta (' .. new_time .. '), tracker reset')
        storage.online_track[player_name] = 0
        return
    end
    if new_time > Public.get_trusted_threshold() and not storage.manually_untrusted[player_name] then
        if not storage.trusted[player_name] then
            if storage.sessions_sticky_resolved[player_name] then
                storage.trusted[player_name] = true
                notify_trust_refreshed(player_name)
                Server.notify_trust_change(player_name, true, 'auto')
            else
                Public.try_dl_manually_untrusted(player_name)
            end
        end
    end
    set_data(session_data_set, player_name, new_time)
    storage.sessions[player_name] = new_time
    storage.online_track[player_name] = player.online_time
end)
local nth_tick_token = Token.register_named('sessions.nth_tick_upload', function(data)
    local player_name = data.name
    Public.try_ul_data(player_name)
end)
local function upload_data()
    local players = game.connected_players
    local count = 0
    for i = 1, #players do
        count = count + 10
        set_timeout_in_ticks(count, nth_tick_token, { name = players[i].name })
    end
end
function Public.try_dl_data(player_name)
    player_name = tostring(player_name)
    try_get_data(session_data_set, player_name, try_download_data_token)
end
function Public.try_dl_manually_untrusted(player_name)
    player_name = tostring(player_name)
    try_get_data(manually_untrusted_data_set, player_name, try_download_manually_untrusted_token)
end
function Public.try_ul_data(player_name)
    player_name = tostring(player_name)
    ensure_init() 
    local sent_tick = storage.sessions_upload_inflight[player_name]
    if sent_tick and game.tick - sent_tick < UPLOAD_INFLIGHT_TTL_TICKS then
        return
    end
    storage.sessions_upload_inflight[player_name] = game.tick
    try_get_data(session_data_set, player_name, try_upload_data_token)
end
function Public.exists(player_name)
    return storage.sessions and storage.sessions[player_name] ~= nil
end
function Public.get_session_table()
    return storage.sessions
end
function Public.get_trusted_table()
    return storage.trusted
end
function Public.get_trusted_player(player)
    if not storage.trusted then return false end
    return player and player.valid and storage.trusted[player.name] or false
end
function Public.is_manually_untrusted(player)
    if not storage.manually_untrusted then return false end
    return player and player.valid and storage.manually_untrusted[player.name] or false
end
function Public.set_trusted_player(player)
    if storage.trusted and player and player.valid then
        storage.trusted[player.name] = true
        storage.manually_untrusted[player.name] = nil
        set_data(manually_untrusted_data_set, player.name, nil)
        Server.notify_trust_change(player.name, true, 'manual')
    end
end
function Public.set_untrusted_player(player)
    if storage.trusted and player and player.valid then
        storage.trusted[player.name] = nil
        storage.manually_untrusted[player.name] = true
        set_data(manually_untrusted_data_set, player.name, 1)
        Server.notify_trust_change(player.name, false)
    end
end
function Public.apply_remote_trust(player_name)
    ensure_init()
    player_name = tostring(player_name)
    if storage.manually_untrusted[player_name] then return false end 
    if storage.trusted[player_name] then return false end            
    storage.trusted[player_name] = true
    notify_trust_refreshed(player_name)
    return true
end
function Public.apply_remote_untrust(player_name)
    ensure_init()
    player_name = tostring(player_name)
    if not storage.trusted[player_name] then return false end
    storage.trusted[player_name] = nil
    notify_trust_refreshed(player_name)
    return true
end
function Public.get_session_player(player)
    if not storage.sessions then return false end
    return player and player.valid and storage.sessions[player.name] or false
end
function Public.get_remaining_trust_ticks(player)
    if not (player and player.valid) then return 0 end
    ensure_init()
    if storage.trusted[player.name] then return 0 end
    local base = storage.sessions[player.name] or 0
    local track = storage.online_track[player.name] or 0
    local delta = player.online_time - track
    if delta < 0 then delta = 0 end 
    local remaining = Public.get_trusted_threshold() - (base + delta)
    if remaining < 0 then remaining = 0 end
    return remaining
end
Event.add(defines.events.on_player_joined_game, function(event)
    ensure_init()
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    storage.sessions_sticky_resolved[player.name] = nil
    Public.try_dl_manually_untrusted(player.name)
end)
Event.add(defines.events.on_player_left_game, function(event)
    ensure_init()
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    Public.try_ul_data(player.name)
end)
Event.add(Public.events.on_player_trusted, function(event)
    ensure_init()
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    Public.set_trusted_player(player)
end)
Event.add(Public.events.on_player_untrusted, function(event)
    ensure_init()
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    Public.set_untrusted_player(player)
end)
Event.on_nth_tick(settings.nth_tick, function()
    ensure_init()
    upload_data()
end)
Server.on_data_set_changed(session_data_set, function(data)
    ensure_init()
    local player = game.get_player(data.key)
    if not player or not player.valid then return end
    if data.value == nil then
        storage.sessions[data.key] = nil
        if storage.trusted[data.key] then storage.trusted[data.key] = nil end
        notify_trust_refreshed(data.key) 
        return
    end
    storage.sessions[data.key] = data.value
    if data.value > Public.get_trusted_threshold() and not storage.manually_untrusted[data.key] then
        if storage.sessions_sticky_resolved[data.key] then
            storage.trusted[data.key] = true
        else
            Public.try_dl_manually_untrusted(data.key)
        end
    else
        storage.trusted[data.key] = nil
    end
    notify_trust_refreshed(data.key) 
end)
Server.on_data_set_changed(manually_untrusted_data_set, function(data)
    ensure_init()
    local player_name = data.key
    if data.value then
        storage.manually_untrusted[player_name] = true
        if storage.trusted[player_name] then
            storage.trusted[player_name] = nil
            notify_trust_refreshed(player_name) 
        end
    else
        storage.manually_untrusted[player_name] = nil
        notify_trust_refreshed(player_name)
    end
end)
return Public
