local CircuitHighlight = require 'lib.circuit_highlight'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'circuit_highlight',
    is_enabled = CircuitHighlight.is_enabled,
    is_user_enabled = CircuitHighlight.is_user_enabled,
    toggle_user = CircuitHighlight.toggle_user,
    sprite_on = 'item/green-wire',
    sprite_off = 'item/red-wire',
    tooltip_on = 'fp-circuit-highlight.button-tooltip-on',
    tooltip_off = 'fp-circuit-highlight.button-tooltip-off',
    toggled_on = 'fp-circuit-highlight.toggled-on',
    toggled_off = 'fp-circuit-highlight.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
