local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local TOGGLE_ID = 'translate_chat'
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.translate-chat-caption' },
    tooltip = { 'fp-admin.translate-chat-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.translate-chat-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
