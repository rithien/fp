local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local TodoList = require 'lib.todo_list'
local TodoListButton = require 'gui.todo_list_button'
local TOGGLE_ID = 'todo_list'
local function refresh_buttons()
    for _, p in pairs(game.connected_players) do
        TodoListButton.refresh(p)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.todo-list-caption' },
    tooltip = { 'fp-admin.todo-list-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(_)
        refresh_buttons()
    end,
    on_change = function(new_state, player)
        TodoList.set_enabled(new_state)
        refresh_buttons()
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.todo-list-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
