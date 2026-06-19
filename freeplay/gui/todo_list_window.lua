local Event = require 'lib.event'
local Gui = require 'gui.init'
local Constants = require 'constants'
local TodoList = require 'lib.todo_list'
local WINDOW_NAME = 'todo_list_window'
local BODY_NAME = 'todo_list_body'
local LIST_NAME = 'todo_list_content'
local CLEAN_DIALOG_NAME = 'todo_list_clean_dialog'
local CLEAN_CB_DONE = 'todo_list_clean_cb_done'
local CLEAN_CB_OPEN = 'todo_list_clean_cb_open'
local CLOSE_ACTION = 'todo_list_close'
local ADD_OPEN_ACTION = 'todo_add_open'              
local TOGGLE_DONE_ACTION = 'todo_toggle_show_done'
local CLEAN_OPEN_ACTION = 'todo_clean_open'
local CLEAN_CONFIRM_ACTION = 'todo_clean_confirm'
local CLEAN_CANCEL_ACTION = 'todo_clean_cancel'
local MARK_DONE_ACTION = 'todo_mark_done'
local MARK_OPEN_ACTION = 'todo_mark_open'
local DETAILS_ACTION = 'todo_toggle_details'
local TAKE_ACTION = 'todo_take'
local EDIT_OPEN_ACTION = 'todo_edit_open'            
local MOVE_UP_ACTION = 'todo_move_up'
local MOVE_DOWN_ACTION = 'todo_move_down'
local MOVE_TOP_ACTION = 'todo_move_top'
local MOVE_BOTTOM_ACTION = 'todo_move_bottom'
local GREY = { r = 0.6, g = 0.6, b = 0.6 }
local TodoListWindow = {}
local function small_button(parent, action, id, caption, tooltip, enabled)
    local b = Gui.add(parent, {
        type = 'button',
        caption = caption,
        tooltip = tooltip,
        enabled = enabled,
        tags = { action = action, task_id = id },
    })
    b.style.width = 26
    b.style.height = 26
    b.style.padding = 0
    return b
end
local function render_open_task(parent, task, view, can_mod)
    local container = parent.add({ type = 'flow', direction = 'vertical' })
    container.style.bottom_padding = 2
    local row = container.add({ type = 'flow', direction = 'horizontal' })
    row.style.vertical_align = 'center'
    row.style.horizontal_spacing = 6
    Gui.add(row, {
        type = 'checkbox',
        state = false,
        enabled = can_mod,
        tooltip = { 'fp-todo-list.mark-done' },
        tags = { action = MARK_DONE_ACTION, task_id = task.id },
    })
    local has_desc = task.description ~= nil and task.description ~= ''
    if has_desc then
        local expanded = view.expanded[task.id] and true or false
        small_button(row, DETAILS_ACTION, task.id,
            expanded and { 'fp-todo-list.details-collapse' } or { 'fp-todo-list.details-expand' },
            { 'fp-todo-list.details' }, true)
    else
        local spacer = row.add({ type = 'empty-widget' })
        spacer.style.width = 26
    end
    local title = row.add({ type = 'label', caption = task.title })
    title.style.horizontally_stretchable = true
    title.style.minimal_width = 240
    title.style.maximal_width = 360
    if task.assignee then
        local a = row.add({ type = 'label', caption = task.assignee })
        a.style.minimal_width = 90
        a.style.font_color = { r = 0.7, g = 0.9, b = 1 }
    else
        local take = Gui.add(row, {
            type = 'button',
            caption = { 'fp-todo-list.take' },
            tooltip = { 'fp-todo-list.take-tooltip' },
            enabled = can_mod,
            tags = { action = TAKE_ACTION, task_id = task.id },
        })
        take.style.minimal_width = 90
        take.style.height = 26
    end
    small_button(row, MOVE_UP_ACTION, task.id, { 'fp-todo-list.sort-up' }, { 'fp-todo-list.move-up' }, can_mod)
    small_button(row, MOVE_DOWN_ACTION, task.id, { 'fp-todo-list.sort-down' }, { 'fp-todo-list.move-down' }, can_mod)
    small_button(row, MOVE_TOP_ACTION, task.id, { 'fp-todo-list.sort-top' }, { 'fp-todo-list.move-top' }, can_mod)
    small_button(row, MOVE_BOTTOM_ACTION, task.id, { 'fp-todo-list.sort-bottom' }, { 'fp-todo-list.move-bottom' }, can_mod)
    local edit = Gui.add(row, {
        type = 'button',
        caption = { 'fp-todo-list.edit' },
        tooltip = { 'fp-todo-list.edit-tooltip' },
        tags = { action = EDIT_OPEN_ACTION, task_id = task.id },
    })
    edit.style.height = 26
    if has_desc and view.expanded[task.id] then
        local drow = container.add({ type = 'flow', direction = 'horizontal' })
        drow.style.left_padding = 32
        local d = drow.add({ type = 'label', caption = task.description })
        d.style.single_line = false
        d.style.maximal_width = 520
        d.style.font_color = { r = 0.85, g = 0.85, b = 0.85 }
    end
end
local function render_done_task(parent, task, can_mod)
    local row = parent.add({ type = 'flow', direction = 'horizontal' })
    row.style.vertical_align = 'center'
    row.style.horizontal_spacing = 6
    row.style.bottom_padding = 1
    Gui.add(row, {
        type = 'checkbox',
        state = true,
        enabled = can_mod,
        tooltip = { 'fp-todo-list.mark-open' },
        tags = { action = MARK_OPEN_ACTION, task_id = task.id },
    })
    local title = row.add({ type = 'label', caption = task.title })
    title.style.horizontally_stretchable = true
    title.style.minimal_width = 240
    title.style.font_color = GREY
    if task.assignee then
        local a = row.add({ type = 'label', caption = task.assignee })
        a.style.minimal_width = 90
        a.style.font_color = GREY
    end
end
local function render_list(player, list)
    list.clear()
    local state = TodoList.state()
    local view = TodoList.view(player)
    if #state.open == 0 then
        list.add({ type = 'label', caption = { 'fp-todo-list.empty' } }).style.font_color = GREY
    else
        for _, task in ipairs(state.open) do
            render_open_task(list, task, view, TodoList.can_modify(player, task))
        end
    end
    if view.show_done and #state.done > 0 then
        local sep = list.add({ type = 'line' })
        sep.style.top_margin = 6
        local hdr = list.add({ type = 'label', caption = { 'fp-todo-list.done-header' } })
        hdr.style.font = 'default-bold'
        hdr.style.font_color = GREY
        for _, task in ipairs(state.done) do
            render_done_task(list, task, TodoList.can_modify(player, task))
        end
    end
end
local function build_body(player, body)
    body.clear()
    local view = TodoList.view(player)
    local toolbar = body.add({ type = 'flow', direction = 'horizontal' })
    toolbar.style.bottom_margin = 6
    toolbar.style.horizontal_spacing = 8
    Gui.add(toolbar, {
        type = 'button',
        style = 'confirm_button',
        caption = { 'fp-todo-list.add-task' },
        tags = { action = ADD_OPEN_ACTION },
    })
    Gui.add(toolbar, {
        type = 'button',
        caption = view.show_done and { 'fp-todo-list.hide-done' } or { 'fp-todo-list.show-done' },
        tags = { action = TOGGLE_DONE_ACTION },
    })
    if TodoList.can_clean(player) then
        Gui.add(toolbar, {
            type = 'button',
            caption = { 'fp-todo-list.clean' },
            tooltip = { 'fp-todo-list.clean-tooltip' },
            tags = { action = CLEAN_OPEN_ACTION },
        })
    end
    local scroll = body.add({
        type = 'scroll-pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
    })
    scroll.style.maximal_height = Constants.todo_list.window_max_height
    scroll.style.minimal_width = 600
    scroll.style.padding = 4
    local list = scroll.add({ type = 'flow', name = LIST_NAME, direction = 'vertical' })
    render_list(player, list)
end
function TodoListWindow.destroy(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, CLEAN_DIALOG_NAME)
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end
function TodoListWindow.open(player)
    if not player or not player.valid then return end
    if not TodoList.is_enabled() then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        player.opened = existing
        return
    end
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-todo-list.window-title' },
        style = 'frame_title',
        ignored_by_interaction = true,
    })
    local dragger = titlebar.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.style.horizontally_stretchable = true
    dragger.style.vertically_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    Gui.add(titlebar, {
        type = 'sprite-button',
        sprite = 'utility/close',
        style = 'frame_action_button',
        tooltip = { 'fp-todo-list.close' },
        tags = { action = CLOSE_ACTION },
    })
    local body = frame.add({
        type = 'frame',
        name = BODY_NAME,
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    body.style.padding = 12
    build_body(player, body)
    frame.force_auto_center()
    player.opened = frame
end
function TodoListWindow.toggle(player)
    if not player or not player.valid then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        TodoListWindow.destroy(player)
    else
        TodoListWindow.open(player)
    end
end
function TodoListWindow.refresh(player)
    if not player or not player.valid then return end
    local win = player.gui.screen[WINDOW_NAME]
    if not win or not win.valid then return end
    local body = win[BODY_NAME]
    if body and body.valid then build_body(player, body) end
end
function TodoListWindow.refresh_all()
    for _, p in pairs(game.connected_players) do
        TodoListWindow.refresh(p)
    end
end
local function after(player, ok, err)
    if ok then
        TodoListWindow.refresh_all()
    else
        if err then player.print({ err }) end
        TodoListWindow.refresh(player)
    end
end
local function open_clean_dialog(player)
    Gui.destroy_if_exists(player.gui.screen, CLEAN_DIALOG_NAME)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = CLEAN_DIALOG_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({ type = 'label', caption = { 'fp-todo-list.clean-title' }, style = 'frame_title',
                   ignored_by_interaction = true })
    local dragger = titlebar.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.style.horizontally_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    local inside = frame.add({ type = 'frame', style = 'inside_shallow_frame', direction = 'vertical' })
    inside.style.padding = 12
    inside.add({ type = 'checkbox', name = CLEAN_CB_DONE, state = true,
                 caption = { 'fp-todo-list.clean-done' } })
    inside.add({ type = 'checkbox', name = CLEAN_CB_OPEN, state = false,
                 caption = { 'fp-todo-list.clean-open' } })
    local buttons = inside.add({ type = 'flow', direction = 'horizontal' })
    buttons.style.top_margin = 8
    Gui.add(buttons, { type = 'button', style = 'confirm_button',
                       caption = { 'fp-todo-list.clean-confirm' }, tags = { action = CLEAN_CONFIRM_ACTION } })
    local spacer = buttons.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    Gui.add(buttons, { type = 'button', style = 'back_button',
                       caption = { 'fp-todo-list.clean-cancel' }, tags = { action = CLEAN_CANCEL_ACTION } })
    frame.force_auto_center()
    player.opened = frame
end
Gui.on_click(CLOSE_ACTION, function(_, player)
    TodoListWindow.destroy(player)
end)
Gui.on_click(TOGGLE_DONE_ACTION, function(_, player)
    if not player or not player.valid then return end
    local view = TodoList.view(player)
    view.show_done = not view.show_done
    TodoListWindow.refresh(player)
end)
Gui.on_click(DETAILS_ACTION, function(event, player)
    if not player or not player.valid then return end
    local id = event.element.tags.task_id
    local view = TodoList.view(player)
    view.expanded[id] = (not view.expanded[id]) or nil
    TodoListWindow.refresh(player)
end)
Gui.on_checked_state_changed(MARK_DONE_ACTION, function(event, player)
    if not player or not player.valid then return end
    local ok, err = TodoList.set_done(player, event.element.tags.task_id, true)
    after(player, ok, err)
end)
Gui.on_checked_state_changed(MARK_OPEN_ACTION, function(event, player)
    if not player or not player.valid then return end
    local ok, err = TodoList.set_done(player, event.element.tags.task_id, false)
    after(player, ok, err)
end)
Gui.on_click(TAKE_ACTION, function(event, player)
    if not player or not player.valid then return end
    local ok, err = TodoList.take(player, event.element.tags.task_id)
    after(player, ok, err)
end)
local move_map = {
    [MOVE_UP_ACTION] = 'up', [MOVE_DOWN_ACTION] = 'down',
    [MOVE_TOP_ACTION] = 'top', [MOVE_BOTTOM_ACTION] = 'bottom',
}
for action, where in pairs(move_map) do
    Gui.on_click(action, function(event, player)
        if not player or not player.valid then return end
        local ok, err = TodoList.move(player, event.element.tags.task_id, where)
        after(player, ok, err)
    end)
end
Gui.on_click(CLEAN_OPEN_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not TodoList.can_clean(player) then return end
    open_clean_dialog(player)
end)
Gui.on_click(CLEAN_CANCEL_ACTION, function(_, player)
    if player and player.valid then Gui.destroy_if_exists(player.gui.screen, CLEAN_DIALOG_NAME) end
end)
Gui.on_click(CLEAN_CONFIRM_ACTION, function(_, player)
    if not player or not player.valid then return end
    local dialog = player.gui.screen[CLEAN_DIALOG_NAME]
    if not dialog or not dialog.valid then return end
    local cb_done, cb_open
    for _, child in pairs(dialog.children) do
        if child[CLEAN_CB_DONE] then cb_done = child[CLEAN_CB_DONE] end
        if child[CLEAN_CB_OPEN] then cb_open = child[CLEAN_CB_OPEN] end
    end
    local which = {
        done = cb_done and cb_done.valid and cb_done.state or false,
        open = cb_open and cb_open.valid and cb_open.state or false,
    }
    Gui.destroy_if_exists(player.gui.screen, CLEAN_DIALOG_NAME)
    if not which.done and not which.open then return end
    local ok, err = TodoList.clean(player, which)
    after(player, ok, err)
end)
Event.add(defines.events.on_gui_closed, function(event)
    local el = event.element
    if not el or not el.valid then return end
    if el.name == WINDOW_NAME or el.name == CLEAN_DIALOG_NAME then
        el.destroy()
    end
end)
return TodoListWindow
