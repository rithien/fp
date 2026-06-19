local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local CircuitHighlight = require 'lib.circuit_highlight'
local CircuitHighlightButton = require 'gui.circuit_highlight_button'
local TOGGLE_ID = 'circuit_highlight'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        CircuitHighlightButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.circuit-highlight-caption' },
    tooltip = { 'fp-admin.circuit-highlight-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(state)
        if not state then CircuitHighlight.clear_all() end
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        if not new_state then CircuitHighlight.clear_all() end
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.circuit-highlight-caption' },
                { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
            { color = { r = 1, g = 1, b = 0 } })
    end,
})
