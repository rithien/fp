local AdminPanel = require 'gui.admin_panel'
local DebugLog = require 'lib.debug_log'
AdminPanel.register_toggle({
    id = 'debug_log',
    caption = { 'fp-admin.debug-log-caption' },
    tooltip = { 'fp-admin.debug-log-tooltip' },
    get_state = DebugLog.is_enabled,
    on_change = function(new_state, player)
        DebugLog.set_enabled(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.debug-log-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
