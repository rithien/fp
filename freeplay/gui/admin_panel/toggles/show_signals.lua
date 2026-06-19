local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local de = defines.events
local TOGGLE_ID = 'show_signals'
local function apply_to_player(player, enabled)
    if not player or not player.valid then return end
    player.game_view_settings.show_rail_block_visualisation = enabled and true or false
end
local function apply(state)
    for _, player in pairs(game.connected_players) do
        apply_to_player(player, state)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.show-signals-caption' },
    tooltip = { 'fp-admin.show-signals-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = apply,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.show-signals-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
Event.add(de.on_player_joined_game, function(event)
    apply_to_player(game.get_player(event.player_index), Config.is_enabled(TOGGLE_ID))
end)
