local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local TurretFillerMenu = require 'gui.turret_filler_menu'
local TOGGLE_ID = 'turret_filler'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        TurretFillerMenu.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.turret-filler-caption' },
    tooltip = { 'fp-admin.turret-filler-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.turret-filler-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, AdminPanel.actor_name(player) },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
