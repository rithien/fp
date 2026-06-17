local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local InserterThroughput = require 'lib.inserter_throughput'
local InserterThroughputButton = require 'gui.inserter_throughput_button'
local TOGGLE_ID = 'inserter_throughput'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        InserterThroughputButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.inserter-throughput-caption' },
    tooltip = { 'fp-admin.inserter-throughput-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(state)
        if not state then InserterThroughput.clear_all() end
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        if not new_state then InserterThroughput.clear_all() end
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.inserter-throughput-caption' },
                { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
            { color = { r = 1, g = 1, b = 0 } })
    end,
})
