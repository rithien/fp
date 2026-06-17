local InserterThroughput = require 'lib.inserter_throughput'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'inserter_throughput',
    is_enabled = InserterThroughput.is_enabled,
    is_user_enabled = InserterThroughput.is_user_enabled,
    toggle_user = InserterThroughput.toggle_user,
    sprite_on = 'item/fast-inserter',
    sprite_off = 'item/inserter',
    tooltip_on = 'fp-inserter-throughput.button-tooltip-on',
    tooltip_off = 'fp-inserter-throughput.button-tooltip-off',
    toggled_on = 'fp-inserter-throughput.toggled-on',
    toggled_off = 'fp-inserter-throughput.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
