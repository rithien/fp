local Event = require 'lib.event'
local DebugLog = require 'lib.debug_log'
local de = defines.events
local Public = {}
function Public.apply_to_player(player)
    if not player or not player.valid then return end
    player.game_view_settings.show_entity_info = true
end
local function apply_for_event(event, source)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local before = player.game_view_settings.show_entity_info
    Public.apply_to_player(player)
    DebugLog.log('[show_entity_info] %s: ON after %s (before=%s)', player.name, source, tostring(before))
end
Event.add(de.on_player_joined_game, function(event) apply_for_event(event, 'join') end)
Event.add(de.on_cutscene_cancelled, function(event) apply_for_event(event, 'cutscene cancelled') end)
Event.add(de.on_cutscene_finished, function(event) apply_for_event(event, 'cutscene finished') end)
return Public
