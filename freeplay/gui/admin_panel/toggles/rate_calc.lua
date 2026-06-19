local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local RateCalc = require 'lib.rate_calc'
local RateCalcButton = require 'gui.rate_calc_button'
local TOGGLE_ID = 'rate_calc'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        RateCalcButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.rate-calc-caption' },
    tooltip = { 'fp-admin.rate-calc-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        RateCalc.set_enabled(new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.rate-calc-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
