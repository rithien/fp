local BeltVisualizer = require 'lib.belt_visualizer'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'belt_visualizer',
    is_enabled = BeltVisualizer.is_enabled,
    is_user_enabled = BeltVisualizer.is_user_enabled,
    toggle_user = BeltVisualizer.toggle_user,
    sprite_on = 'item/express-transport-belt',
    sprite_off = 'item/transport-belt',
    tooltip_on = 'fp-belt-visualizer.button-tooltip-on',
    tooltip_off = 'fp-belt-visualizer.button-tooltip-off',
    toggled_on = 'fp-belt-visualizer.toggled-on',
    toggled_off = 'fp-belt-visualizer.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
