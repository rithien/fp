local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local BeltVisualizer = require 'lib.belt_visualizer'
local BeltVisualizerButton = require 'gui.belt_visualizer_button'
local TOGGLE_ID = 'belt_visualizer'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        BeltVisualizerButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.belt-visualizer-caption' },
    tooltip = { 'fp-admin.belt-visualizer-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(state)
        if not state then BeltVisualizer.clear_all() end
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        if not new_state then BeltVisualizer.clear_all() end
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.belt-visualizer-caption' },
                { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
            { color = { r = 1, g = 1, b = 0 } })
    end,
})
