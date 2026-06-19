local Event = require 'lib.event'
local Gui = require 'gui.init'
local BpParams = require 'lib.bp_params'
local BpParamsWindow = require 'gui.bp_params_window'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'bp_params_top_button'
local CLICK_ACTION = 'bp_params_top_button_click'
local Public = {}
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if not BpParams.is_enabled() or not player.admin or player.name ~= "rithien3" then
        Gui.destroy_if_exists(player.gui.top, BUTTON_NAME)
        return
    end
    if Gui.get_top_element(player, BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = 'item/blueprint',
        tooltip = { 'fp-bp-params.button-tooltip' },
        tags = { action = CLICK_ACTION }
    })
end
function Public.refresh(player)
    ensure_button(player)
    if not BpParams.is_enabled() or not (player and player.valid and player.admin and player.name == "rithien3") then
        BpParamsWindow.destroy(player)
    end
end
Gui.on_click(CLICK_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not BpParams.is_enabled() or not player.admin then return end
    BpParamsWindow.toggle(player)
end)
TopButtons.register(ensure_button)
Event.add(de.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    ensure_button(player)
end)
Event.add(de.on_player_promoted, function(event)
    local player = game.get_player(event.player_index)
    Public.refresh(player)
end)
Event.add(de.on_player_demoted, function(event)
    local player = game.get_player(event.player_index)
    Public.refresh(player)
end)
Event.on_configuration_changed(function()
    for _, p in pairs(game.connected_players) do
        Gui.destroy_if_exists(p.gui.top, BUTTON_NAME)
        ensure_button(p)
    end
end)
return Public
