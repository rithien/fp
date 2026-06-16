local Event = require 'lib.event'
local Gui = require 'gui.init'
local RateCalc = require 'lib.rate_calc'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'rate_calc_top_button'
local CLICK_ACTION = 'rate_calc_top_button_click'
local Public = {}
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if not RateCalc.is_enabled() then
        Gui.destroy_if_exists(player.gui.top, BUTTON_NAME)
        return
    end
    if Gui.get_top_element(player, BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = 'utility/side_menu_production_icon',
        tooltip = { 'fp-rate-calc.button-tooltip' },
        tags = { action = CLICK_ACTION }
    })
end
function Public.refresh(player)
    ensure_button(player)
end
Gui.on_click(CLICK_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not RateCalc.is_enabled() then return end
    if RateCalc.is_in_mode(player.index) then
        RateCalc.exit_mode(player, true)
        player.print({ 'fp-rate-calc.cancelled' })
    else
        RateCalc.enter_mode(player)
    end
end)
TopButtons.register(ensure_button)
Event.add(de.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    ensure_button(player)
end)
Event.on_configuration_changed(function()
    for _, p in pairs(game.connected_players) do
        Gui.destroy_if_exists(p.gui.top, BUTTON_NAME)
        ensure_button(p)
    end
end)
return Public
