local Event = require 'lib.event'
local Config = require 'lib.config'
local Session = require 'lib.sessions'
local Constants = require 'constants'
local DebugLog = require 'lib.debug_log'
local Tasks = require 'lib.todo_list.tasks'
local TOGGLE_ID = 'todo_list'
local TodoList = {}
local function ensure_storage()
    if not storage.todo_list then
        storage.todo_list = { open = {}, done = {}, next_id = 1, view = {} }
    end
    if not storage.todo_list.view then storage.todo_list.view = {} end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
Event.add(defines.events.on_player_left_game, function(event)
    if storage.todo_list and storage.todo_list.view then
        storage.todo_list.view[event.player_index] = nil
    end
end)
function TodoList.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function TodoList.set_enabled(new_state)
    Config.set(TOGGLE_ID, new_state)
end
function TodoList.state()
    ensure_storage()
    return storage.todo_list
end
function TodoList.view(player)
    ensure_storage()
    local v = storage.todo_list.view
    local idx = player.index
    if not v[idx] then v[idx] = { show_done = false, expanded = {} } end
    if not v[idx].expanded then v[idx].expanded = {} end
    return v[idx]
end
function TodoList.can_modify(player, task)
    if not player or not player.valid then return false end
    if player.admin then return true end
    if Session.get_trusted_player(player) then return true end
    return task ~= nil and task.created_by == player.name
end
function TodoList.can_clean(player)
    if not player or not player.valid then return false end
    return player.admin or Session.get_trusted_player(player) ~= nil
end
function TodoList.find(id)
    local task, _, _, status = Tasks.find(TodoList.state(), id)
    return task, status
end
local function sanitize_title(text)
    if type(text) ~= 'string' then return nil, 'fp-todo-list.empty-title-error' end
    local trimmed = text:match('^%s*(.-)%s*$') or ''
    if trimmed == '' then return nil, 'fp-todo-list.empty-title-error' end
    trimmed = trimmed:gsub('[\r\n]+', ' ')
    local max = Constants.todo_list.max_title_len
    if #trimmed > max then trimmed = trimmed:sub(1, max) end
    return trimmed, nil
end
local function sanitize_description(text)
    if type(text) ~= 'string' then return '' end
    local trimmed = text:match('^%s*(.-)%s*$') or ''
    local max = Constants.todo_list.max_desc_len
    if #trimmed > max then trimmed = trimmed:sub(1, max) end
    return trimmed
end
local function sanitize_assignee(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local p = game.get_player(name)
    if p then return p.name end
    return nil
end
function TodoList.add(player, title, description, assignee)
    if not TodoList.is_enabled() then return false, nil end
    if not player or not player.valid then return false, nil end
    local clean_title, err = sanitize_title(title)
    if err then return false, err end
    local task = Tasks.add(TodoList.state(), {
        title = clean_title,
        description = sanitize_description(description),
        assignee = sanitize_assignee(assignee),
        author = player.name,
    })
    DebugLog.log('[todo_list] add id=%d by=%s title=%q', task.id, player.name, task.title)
    return true, nil
end
function TodoList.edit(player, id, title, description, assignee)
    local task = TodoList.find(id)
    if not task then return false, nil end
    if not TodoList.can_modify(player, task) then
        DebugLog.log('[todo_list] DENY edit id=%d player=%s (not owner)', id, player.name)
        return false, 'fp-todo-list.no-permission'
    end
    local clean_title, err = sanitize_title(title)
    if err then return false, err end
    Tasks.edit(TodoList.state(), id, {
        title = clean_title,
        description = sanitize_description(description),
        assignee = sanitize_assignee(assignee),
        editor = player.name,
    })
    DebugLog.log('[todo_list] edit id=%d by=%s', id, player.name)
    return true, nil
end
function TodoList.delete(player, id)
    local task = TodoList.find(id)
    if not task then return false, nil end
    if not TodoList.can_modify(player, task) then
        DebugLog.log('[todo_list] DENY delete id=%d player=%s (not owner)', id, player.name)
        return false, 'fp-todo-list.no-permission'
    end
    Tasks.delete(TodoList.state(), id)
    DebugLog.log('[todo_list] delete id=%d by=%s', id, player.name)
    return true, nil
end
function TodoList.set_done(player, id, done)
    local task = TodoList.find(id)
    if not task then return false, nil end
    if not TodoList.can_modify(player, task) then
        DebugLog.log('[todo_list] DENY set_done id=%d player=%s (not owner)', id, player.name)
        return false, 'fp-todo-list.no-permission'
    end
    local ok
    if done then ok = Tasks.mark_done(TodoList.state(), id)
    else ok = Tasks.mark_open(TodoList.state(), id) end
    if not ok then return false, nil end
    DebugLog.log('[todo_list] set_done id=%d done=%s by=%s', id, tostring(done), player.name)
    return true, nil
end
function TodoList.take(player, id)
    local task = TodoList.find(id)
    if not task then return false, nil end
    if not TodoList.can_modify(player, task) then
        DebugLog.log('[todo_list] DENY take id=%d player=%s (not owner)', id, player.name)
        return false, 'fp-todo-list.no-permission'
    end
    Tasks.set_assignee(TodoList.state(), id, player.name, player.name)
    DebugLog.log('[todo_list] take id=%d by=%s', id, player.name)
    return true, nil
end
function TodoList.move(player, id, where)
    local task = TodoList.find(id)
    if not task then return false, nil end
    if not TodoList.can_modify(player, task) then
        DebugLog.log('[todo_list] DENY move id=%d player=%s (not owner)', id, player.name)
        return false, 'fp-todo-list.no-permission'
    end
    local ok = Tasks.move(TodoList.state(), id, where)
    if not ok then return false, nil end
    DebugLog.log('[todo_list] move id=%d where=%s by=%s', id, where, player.name)
    return true, nil
end
function TodoList.clean(player, which)
    if not TodoList.can_clean(player) then
        DebugLog.log('[todo_list] DENY clean player=%s (not trusted/admin)', player.name)
        return false, 'fp-todo-list.no-permission'
    end
    local removed = Tasks.clean(TodoList.state(), which)
    DebugLog.log('[todo_list] clean removed=%d (done=%s open=%s) by=%s',
        removed, tostring(which.done), tostring(which.open), player.name)
    return true, nil
end
return TodoList
