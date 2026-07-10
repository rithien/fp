local AdminPanel = require 'gui.admin_panel'
local Emit = require 'lib.translate_chat_emit'
local Sink = require 'lib.translation_sink'
local TESTER_NAME = 'rithien3'   
local SPEAKER = 'TestBot'        
local TEST_TEXT = {
    en = "Hello! This is a test message simulating another player's chat.",
    pl = 'Cześć! To jest testowa wiadomość symulująca czat innego gracza.',
}
local function is_tester(player)
    return player.name == TESTER_NAME
end
local function player_locale(player)
    local loc = player.locale
    if type(loc) == 'string' and loc ~= '' then return loc end
    return 'en'
end
AdminPanel.register_test({
    id = 'sim_foreign_chat',
    caption = { 'fp-admin.test-sim-chat-caption' },
    tooltip = { 'fp-admin.test-sim-chat-tooltip' },
    visible = is_tester,
    on_click = function(player)
        local loc = player_locale(player)
        local source = (loc:sub(1, 2) == 'en') and 'pl' or 'en'
        Emit.emit(SPEAKER, TEST_TEXT[source], { loc, source })
        player.print({ 'fp-admin.test-sim-chat-emitted', SPEAKER, source, loc })
    end,
})
AdminPanel.register_test({
    id = 'sim_fpo_local',
    caption = { 'fp-admin.test-sim-fpo-caption' },
    tooltip = { 'fp-admin.test-sim-fpo-tooltip' },
    visible = is_tester,
    on_click = function(player)
        local loc = player_locale(player)
        Sink.dispatch({
            speaker = SPEAKER,
            original = 'Local sink test — original text (overhead fallback).',
            t = { [loc] = 'Local sink test — translated variant for your locale "' .. loc .. '".' },
            chat = SPEAKER .. ' [test] Local sink test — universal chat line.',
        })
        player.print({ 'fp-admin.test-sim-fpo-done' })
    end,
})
