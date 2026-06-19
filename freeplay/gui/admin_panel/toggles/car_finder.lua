local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local CarFinderButton = require 'gui.car_finder_button'
local TOGGLE_ID = 'car_finder'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        CarFinderButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.car-finder-caption' },
    tooltip = { 'fp-admin.car-finder-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.car-finder-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
