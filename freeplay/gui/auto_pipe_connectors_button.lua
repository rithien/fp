local AutoPipeConnectors = require 'lib.auto_pipe_connectors'
local ToolsPanel = require 'gui.tools_panel'
local Public = {}
ToolsPanel.register({
    id = 'auto_pipe_connectors',
    is_enabled = AutoPipeConnectors.is_enabled,
    is_user_enabled = AutoPipeConnectors.is_user_enabled,
    toggle_user = AutoPipeConnectors.toggle_user,
    sprite_on = 'item/pipe-to-ground',
    sprite_off = 'item/pipe',
    tooltip_on = 'fp-auto-pipe-connectors.button-tooltip-on',
    tooltip_off = 'fp-auto-pipe-connectors.button-tooltip-off',
    toggled_on = 'fp-auto-pipe-connectors.toggled-on',
    toggled_off = 'fp-auto-pipe-connectors.toggled-off',
})
Public.refresh = ToolsPanel.refresh
return Public
