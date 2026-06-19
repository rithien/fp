local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local SpawnLogo = require 'lib.spawn_logo'
local TOGGLE_ID = 'spawn_logo'
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.spawn-logo-caption' },
    tooltip = { 'fp-admin.spawn-logo-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(state) SpawnLogo.apply(state) end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        SpawnLogo.apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.spawn-logo-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
