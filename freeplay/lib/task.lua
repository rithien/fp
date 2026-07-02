local Event = require 'lib.event'
local Token = require 'lib.token'
local Task = {}
local function ensure_init()
    if not storage.task_callbacks then
        storage.task_callbacks = {}
    end
end
local function handler_error(err)
    log('\n\t' .. debug.traceback(err))
end
local function on_tick(event)
    local cbs = storage.task_callbacks
    if not cbs or #cbs == 0 then
        return
    end
    local tick = event.tick
    while cbs[1] and cbs[1].time <= tick do
        local cb = table.remove(cbs, 1)
        if type(cb.func_token) == 'string' then
            local fn = Token.get(cb.func_token)
            if fn then
                xpcall(fn, handler_error, cb.params)
            end
        end
    end
end
function Task.set_timeout_in_ticks(ticks, func_token, params)
    if not game then
        error('cannot call when game is not available', 2)
    end
    if type(func_token) ~= 'string' then
        error('Task.set_timeout_in_ticks: func_token must be a named token (Token.register_named)', 2)
    end
    ensure_init()
    local time = game.tick + ticks
    local cb = { time = time, func_token = func_token, params = params }
    local cbs = storage.task_callbacks
    for i = 1, #cbs do
        if cbs[i].time > time then
            table.insert(cbs, i, cb)
            return
        end
    end
    cbs[#cbs + 1] = cb
end
Event.on_init(ensure_init)
Event.on_configuration_changed(ensure_init)
Event.add(defines.events.on_tick, on_tick)
return Task
