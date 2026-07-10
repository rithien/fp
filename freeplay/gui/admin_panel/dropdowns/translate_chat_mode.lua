local AdminPanel = require 'gui.admin_panel'
local ChatMode = require 'lib.translation_chat'
AdminPanel.register_dropdown({
    id = 'translate_chat_mode',
    caption = { 'fp-admin.chat-mode-caption' },
    tooltip = { 'fp-admin.chat-mode-tooltip' },
    choices = ChatMode.get_mode_choices(),
    get_value = function() return ChatMode.get_mode() end,
    on_change = function(key, player)
        ChatMode.set_mode(key)
        local label = key  
        for _, c in ipairs(ChatMode.get_mode_choices()) do
            if c.key == key then label = c.caption; break end
        end
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.chat-mode-caption' },
                     label, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
