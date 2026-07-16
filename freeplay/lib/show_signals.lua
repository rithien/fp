local Event = require 'lib.event'
local Config = require 'lib.config'
local de = defines.events
local TOGGLE_ID = 'show_signals'
local Public = {}
local function ensure_storage()
    if not storage.show_signals then
        storage.show_signals = { user_disabled = {} }
    elseif not storage.show_signals.user_disabled then
        storage.show_signals.user_disabled = {}
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    ensure_storage()
    return not storage.show_signals.user_disabled[index]
end
function Public.is_active_for(index)
    return Config.is_enabled(TOGGLE_ID) and Public.is_user_enabled(index)
end
function Public.apply_to_player(player)
    if not player or not player.valid then return end
    player.game_view_settings.show_rail_block_visualisation = Public.is_active_for(player.index)
end
function Public.apply_all()
    for _, player in pairs(game.connected_players) do
        Public.apply_to_player(player)
    end
end
function Public.toggle_user(index)
    ensure_storage()
    local disabled = storage.show_signals.user_disabled
    if disabled[index] then
        disabled[index] = nil
    else
        disabled[index] = true
    end
    Public.apply_to_player(game.get_player(index))
    return not disabled[index]
end
Event.add(de.on_player_joined_game, function(event)
    Public.apply_to_player(game.get_player(event.player_index))
end)
return Public
