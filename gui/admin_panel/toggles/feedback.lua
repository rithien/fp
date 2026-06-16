local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Feedback = require 'lib.feedback'
local FeedbackButton = require 'gui.feedback_button'
local TOGGLE_ID = 'feedback'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        FeedbackButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.feedback-caption' },
    tooltip = { 'fp-admin.feedback-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Feedback.set_enabled(new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.feedback-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
