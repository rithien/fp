local EvenDistribution = require 'lib.even_distribution'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'even_distribution',
    is_enabled = EvenDistribution.is_enabled,
    is_user_enabled = EvenDistribution.is_user_enabled,
    toggle_user = EvenDistribution.toggle_user,
    sprite_on = 'item/fast-inserter',
    sprite_off = 'item/burner-inserter',
    tooltip_on = 'fp-even-distribution.button-tooltip-on',
    tooltip_off = 'fp-even-distribution.button-tooltip-off',
    toggled_on = 'fp-even-distribution.toggled-on',
    toggled_off = 'fp-even-distribution.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
