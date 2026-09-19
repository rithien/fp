local Event = require 'lib.event'
local Server = require 'lib.server'
local DebugLog = require 'lib.debug_log'
local TAG = '[PLAYER-LEAVE]'
local Public = {}
local reason_names = {}
if defines.disconnect_reason then
    for name, id in pairs(defines.disconnect_reason) do
        reason_names[id] = name
    end
end
function Public.reason_name(reason)
    return reason_names[reason] or 'quit'
end
Event.add(defines.events.on_player_left_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local reason = Public.reason_name(event.reason)
    DebugLog.log('[player_presence] %s left, reason=%s', player.name, reason)
    Server.output_data(TAG .. helpers.table_to_json({ player = player.name, reason = reason }))
end)
return Public
