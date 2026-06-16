local Public = {}
local init_event_name = -1
local load_event_name = -2
local configuration_changed_name = -3
local event_handlers = {}
local on_nth_tick_event_handlers = {}
local xpcall = xpcall
local trace = debug.traceback
local log = log
local script_on_event = script.on_event
local script_on_nth_tick = script.on_nth_tick
local script_on_configuration_changed = script.on_configuration_changed
local function handler_error(err)
    log('\n\t' .. trace(err))
end
local function call_handlers(handlers, event)
    for i = 1, #handlers do
        if _DEBUG then
            local handler = handlers[i]
            handler(event)
        else
            xpcall(handlers[i], handler_error, event)
        end
    end
end
local function on_event(event)
    local handlers = event_handlers[event.name]
    if not handlers then
        handlers = event_handlers[event.input_name]
    end
    call_handlers(handlers, event)
end
local function on_init()
    _LIFECYCLE = 5 
    local handlers = event_handlers[init_event_name]
    call_handlers(handlers)
    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil
    _LIFECYCLE = 8 
end
local function on_load()
    _LIFECYCLE = 6 
    local handlers = event_handlers[load_event_name]
    call_handlers(handlers)
    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil
    _LIFECYCLE = 8 
end
local function configuration_changed()
    _LIFECYCLE = 7 
    local handlers = event_handlers[configuration_changed_name]
    call_handlers(handlers)
    event_handlers[configuration_changed_name] = nil
    _LIFECYCLE = 8 
end
local function on_nth_tick_event(event)
    local handlers = on_nth_tick_event_handlers[event.nth_tick]
    call_handlers(handlers, event)
end
function Public.add(event_name, handler)
    local handlers = event_handlers[event_name]
    if not handlers then
        event_handlers[event_name] = { handler }
        script_on_event(event_name, on_event)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script_on_event(event_name, on_event)
        end
    end
end
function Public.on_init(handler)
    local handlers = event_handlers[init_event_name]
    if not handlers then
        event_handlers[init_event_name] = { handler }
        script.on_init(on_init)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script.on_init(on_init)
        end
    end
end
function Public.on_configuration_changed(handler)
    local handlers = event_handlers[configuration_changed_name]
    if not handlers then
        event_handlers[configuration_changed_name] = { handler }
        script_on_configuration_changed(configuration_changed)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script.on_configuration_changed(configuration_changed)
        end
    end
end
function Public.on_load(handler)
    local handlers = event_handlers[load_event_name]
    if not handlers then
        event_handlers[load_event_name] = { handler }
        script.on_load(on_load)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script.on_load(on_load)
        end
    end
end
function Public.on_nth_tick(tick, handler)
    local handlers = on_nth_tick_event_handlers[tick]
    if not handlers then
        on_nth_tick_event_handlers[tick] = { handler }
        script_on_nth_tick(tick, on_nth_tick_event)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script_on_nth_tick(tick, on_nth_tick_event)
        end
    end
end
function Public.get_event_handlers()
    return event_handlers
end
function Public.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end
return Public
