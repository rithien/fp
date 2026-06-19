local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local BpParams = require 'lib.bp_params'
local BpParamsButton = require 'gui.bp_params_button'
local TOGGLE_ID = 'bp_params'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        BpParamsButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.bp-params-caption' },
    tooltip = { 'fp-admin.bp-params-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        BpParams.set_enabled(new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.bp-params-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
