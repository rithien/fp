local Event = require 'lib.event'
local Gui = require 'gui.init'
local TodoList = require 'lib.todo_list'
local TodoListWindow = require 'gui.todo_list_window'
local DIALOG_NAME = 'todo_list_dialog'
local TITLE_FIELD = 'todo_dialog_title'
local DESC_FIELD = 'todo_dialog_desc'
local ASSIGNEE_FIELD = 'todo_dialog_assignee'
local SAVE_ACTION = 'todo_dialog_save'
local CANCEL_ACTION = 'todo_dialog_cancel'
local DELETE_ACTION = 'todo_dialog_delete'
local CONFIRM_ACTION = 'todo_dialog_confirm'         
local ASSIGNEE_NOOP = 'todo_dialog_assignee_noop'    
local function find_descendant(parent, name)
    local direct = parent[name]
    if direct and direct.valid then return direct end
    for _, child in pairs(parent.children) do
        local found = find_descendant(child, name)
        if found then return found end
    end
    return nil
end
local function build_assignee_choices(current)
    local items = { { 'fp-todo-list.unassigned' } }
    local names = {}
    local seen = {}
    for _, p in pairs(game.connected_players) do
        names[#names + 1] = p.name
        items[#items + 1] = p.name
        seen[p.name] = true
    end
    if current and not seen[current] then
        names[#names + 1] = current
        items[#items + 1] = current
    end
    local selected = 1
    for i = 1, #names do
        if names[i] == current then selected = i + 1 break end
    end
    return items, names, selected
end
local function close_dialog(player)
    if player and player.valid then
        Gui.destroy_if_exists(player.gui.screen, DIALOG_NAME)
        TodoListWindow.refocus(player) 
    end
end
local function open_dialog(player, task)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, DIALOG_NAME)
    local is_edit = task ~= nil
    local frame = player.gui.screen.add({
        type = 'frame',
        name = DIALOG_NAME,
        direction = 'vertical',
        tags = { mode = is_edit and 'edit' or 'add', task_id = is_edit and task.id or nil },
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = is_edit and { 'fp-todo-list.dialog-edit-title' } or { 'fp-todo-list.dialog-add-title' },
        style = 'frame_title',
        ignored_by_interaction = true,
    })
    local dragger = titlebar.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.style.horizontally_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    local inside = frame.add({ type = 'frame', style = 'inside_shallow_frame', direction = 'vertical' })
    inside.style.padding = 12
    inside.style.minimal_width = 420
    inside.add({ type = 'label', caption = { 'fp-todo-list.field-title' } })
    local title_field = Gui.add(inside, {
        type = 'textfield',
        name = TITLE_FIELD,
        text = is_edit and task.title or '',
        icon_selector = true,
        tags = { action = CONFIRM_ACTION },
    })
    title_field.style.horizontally_stretchable = true
    title_field.style.bottom_margin = 6
    inside.add({ type = 'label', caption = { 'fp-todo-list.field-description' } })
    local desc_field = inside.add({
        type = 'text-box',
        name = DESC_FIELD,
        text = is_edit and (task.description or '') or '',
    })
    desc_field.word_wrap = true
    desc_field.style.horizontally_stretchable = true
    desc_field.style.maximal_width = 0
    desc_field.style.minimal_height = 100
    desc_field.style.maximal_height = 180
    desc_field.style.bottom_margin = 6
    inside.add({ type = 'label', caption = { 'fp-todo-list.field-assignee' } })
    local items, names, selected = build_assignee_choices(is_edit and task.assignee or nil)
    local dd = Gui.add(inside, {
        type = 'drop-down',
        name = ASSIGNEE_FIELD,
        items = items,
        selected_index = selected,
        tags = { action = ASSIGNEE_NOOP, names = names },
    })
    dd.style.horizontally_stretchable = true
    dd.style.bottom_margin = 6
    if is_edit then
        inside.add({ type = 'label', caption = { 'fp-todo-list.created-by', task.created_by } }).style.font_color =
            { r = 0.7, g = 0.7, b = 0.7 }
        inside.add({ type = 'label', caption = { 'fp-todo-list.updated-by', task.updated_by } }).style.font_color =
            { r = 0.7, g = 0.7, b = 0.7 }
    end
    local buttons = inside.add({ type = 'flow', direction = 'horizontal' })
    buttons.style.top_margin = 8
    Gui.add(buttons, {
        type = 'button',
        style = 'confirm_button',
        caption = { 'fp-todo-list.save' },
        tags = { action = SAVE_ACTION },
    })
    if is_edit then
        local del = Gui.add(buttons, {
            type = 'button',
            caption = { 'fp-todo-list.delete' },
            tags = { action = DELETE_ACTION },
        })
        del.style.left_margin = 8
        del.style.font_color = { r = 1, g = 0.6, b = 0.6 }
    end
    local spacer = buttons.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    Gui.add(buttons, {
        type = 'button',
        style = 'back_button',
        caption = { 'fp-todo-list.cancel' },
        tags = { action = CANCEL_ACTION },
    })
    frame.force_auto_center()
    TodoListWindow.open_over_list(player, frame)
    title_field.focus()
end
local function do_save(player)
    if not player or not player.valid then return end
    local dialog = player.gui.screen[DIALOG_NAME]
    if not dialog or not dialog.valid then return end
    local title_el = find_descendant(dialog, TITLE_FIELD)
    local desc_el = find_descendant(dialog, DESC_FIELD)
    local dd = find_descendant(dialog, ASSIGNEE_FIELD)
    if not title_el or not desc_el or not dd then return end
    local names = dd.tags.names or {}
    local idx = dd.selected_index
    local assignee = (idx and idx > 1) and names[idx - 1] or nil
    local mode = dialog.tags.mode
    local ok, err
    if mode == 'edit' then
        ok, err = TodoList.edit(player, dialog.tags.task_id, title_el.text, desc_el.text, assignee)
    else
        ok, err = TodoList.add(player, title_el.text, desc_el.text, assignee)
    end
    if ok then
        close_dialog(player)
        TodoListWindow.refresh_all()
    elseif err then
        player.print({ err })
    end
end
Gui.on_click('todo_add_open', function(_, player)
    if not player or not player.valid then return end
    if not TodoList.is_enabled() then return end
    open_dialog(player, nil)
end)
Gui.on_click('todo_edit_open', function(event, player)
    if not player or not player.valid then return end
    local id = event.element.tags.task_id
    local task = TodoList.find(id)
    if not task then return end
    open_dialog(player, task)
end)
Gui.on_click(SAVE_ACTION, function(_, player) do_save(player) end)
Gui.on_confirmed(CONFIRM_ACTION, function(_, player) do_save(player) end)
Gui.on_click(CANCEL_ACTION, function(_, player) close_dialog(player) end)
Gui.on_click(DELETE_ACTION, function(_, player)
    if not player or not player.valid then return end
    local dialog = player.gui.screen[DIALOG_NAME]
    if not dialog or not dialog.valid or dialog.tags.mode ~= 'edit' then return end
    local ok, err = TodoList.delete(player, dialog.tags.task_id)
    if ok then
        close_dialog(player)
        TodoListWindow.refresh_all()
    elseif err then
        player.print({ err })
    end
end)
Event.add(defines.events.on_gui_closed, function(event)
    local el = event.element
    if el and el.valid and el.name == DIALOG_NAME then
        el.destroy()
        TodoListWindow.refocus(game.get_player(event.player_index)) 
    end
end)
local TodoListDialog = {}
return TodoListDialog
