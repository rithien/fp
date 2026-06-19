local Tasks = {}
function Tasks.find(state, id)
    for i, t in ipairs(state.open) do
        if t.id == id then return t, state.open, i, 'open' end
    end
    for i, t in ipairs(state.done) do
        if t.id == id then return t, state.done, i, 'done' end
    end
    return nil
end
function Tasks.add(state, fields)
    local id = state.next_id
    state.next_id = id + 1
    local task = {
        id = id,
        title = fields.title,
        description = fields.description or '',
        assignee = fields.assignee,        
        created_by = fields.author,
        updated_by = fields.author,
    }
    table.insert(state.open, task)
    return task
end
function Tasks.edit(state, id, fields)
    local task = Tasks.find(state, id)
    if not task then return false end
    task.title = fields.title
    task.description = fields.description or ''
    task.assignee = fields.assignee
    task.updated_by = fields.editor
    return true
end
function Tasks.set_assignee(state, id, assignee, editor)
    local task = Tasks.find(state, id)
    if not task then return false end
    task.assignee = assignee
    task.updated_by = editor
    return true
end
function Tasks.delete(state, id)
    local _, list, index = Tasks.find(state, id)
    if not list then return false end
    table.remove(list, index)
    return true
end
function Tasks.mark_done(state, id)
    local task, list, index, status = Tasks.find(state, id)
    if not task or status ~= 'open' then return false end
    table.remove(list, index)
    table.insert(state.done, task)
    return true
end
function Tasks.mark_open(state, id)
    local task, list, index, status = Tasks.find(state, id)
    if not task or status ~= 'done' then return false end
    table.remove(list, index)
    table.insert(state.open, task)
    return true
end
function Tasks.move(state, id, where)
    local _, list, index, status = Tasks.find(state, id)
    if not list or status ~= 'open' then return false end
    local n = #list
    if n < 2 then return false end
    if where == 'up' then
        if index <= 1 then return false end
        list[index], list[index - 1] = list[index - 1], list[index]
    elseif where == 'down' then
        if index >= n then return false end
        list[index], list[index + 1] = list[index + 1], list[index]
    elseif where == 'top' then
        if index <= 1 then return false end
        local t = table.remove(list, index)
        table.insert(list, 1, t)
    elseif where == 'bottom' then
        if index >= n then return false end
        local t = table.remove(list, index)
        table.insert(list, t)
    else
        return false
    end
    return true
end
function Tasks.clean(state, which)
    local removed = 0
    if which.open then
        removed = removed + #state.open
        state.open = {}
    end
    if which.done then
        removed = removed + #state.done
        state.done = {}
    end
    return removed
end
return Tasks
