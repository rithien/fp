local Event = require 'lib.event'
local Gui = require 'gui.init'
local TodoList = require 'lib.todo_list'
local TodoListWindow = require 'gui.todo_list_window'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'todo_list_top_button'
local CLICK_ACTION = 'todo_list_button_click'
local Public = {}
local function update_badge(player)
    local button = Gui.get_top_element(player, BUTTON_NAME)
    if not button then return end
    local open_count, unassigned_count = TodoList.counts()
    button.number = open_count > 0 and open_count or nil
    button.tooltip = {
        '',
        { 'fp-todo-list.button-tooltip' },
        '\n\n',
        { 'fp-todo-list.button-tooltip-counts', open_count, unassigned_count }
    }
end
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if not TodoList.is_enabled() then
        Gui.destroy_if_exists(player.gui.top, BUTTON_NAME)
        return
    end
    if Gui.get_top_element(player, BUTTON_NAME) then
        update_badge(player)
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = 'item/blueprint-book',
        tooltip = { 'fp-todo-list.button-tooltip' },
        tags = { action = CLICK_ACTION }
    })
    update_badge(player)
end
function Public.update_all_badges()
    for _, p in pairs(game.connected_players) do
        update_badge(p)
    end
end
function Public.refresh(player)
    ensure_button(player)
    if not TodoList.is_enabled() then
        TodoListWindow.destroy(player)
    end
end
Gui.on_click(CLICK_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not TodoList.is_enabled() then return end
    TodoListWindow.toggle(player)
end)
TopButtons.register(ensure_button)
TodoListWindow.register_badge_refresher(Public.update_all_badges)
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
