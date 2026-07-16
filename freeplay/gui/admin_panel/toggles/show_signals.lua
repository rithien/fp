local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local ShowSignals = require 'lib.show_signals'
local ShowSignalsButton = require 'gui.show_signals_button'
local TOGGLE_ID = 'show_signals'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        ShowSignalsButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.show-signals-caption' },
    tooltip = { 'fp-admin.show-signals-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function()
        ShowSignals.apply_all()
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        ShowSignals.apply_all()
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.show-signals-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
