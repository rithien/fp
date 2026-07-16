local ShowSignals = require 'lib.show_signals'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'show_signals',
    is_enabled = ShowSignals.is_enabled,
    is_user_enabled = ShowSignals.is_user_enabled,
    toggle_user = ShowSignals.toggle_user,
    sprite_on = 'item/rail-signal',
    sprite_off = 'item/rail',
    tooltip_on = 'fp-show-signals.button-tooltip-on',
    tooltip_off = 'fp-show-signals.button-tooltip-off',
    toggled_on = 'fp-show-signals.toggled-on',
    toggled_off = 'fp-show-signals.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
