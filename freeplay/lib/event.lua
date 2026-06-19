local EventCore = require 'lib.event_core'
local core_add = EventCore.add
local core_on_init = EventCore.on_init
local core_on_load = EventCore.on_load
local core_on_nth_tick = EventCore.on_nth_tick
local core_on_configuration_changed = EventCore.on_configuration_changed
local raise_event = script.raise_event
local generate_event_name = script.generate_event_name
local get_event_filter = script.get_event_filter
local Event = {}
function Event.add(event_name, handler)
    if _LIFECYCLE == 8 then
        error('Calling Event.add after on_init() or on_load() has run is a desync risk.', 2)
    end
    core_add(event_name, handler)
end
function Event.on_init(handler)
    if _LIFECYCLE == 8 then
        error('Calling Event.on_init after on_init() or on_load() has run is a desync risk.', 2)
    end
    core_on_init(handler)
end
function Event.raise(handler, data)
    if data then
        if type(data) ~= 'table' then
            return error('When raising an event, data must be of type table')
        end
    end
    raise_event(handler, data or {})
end
function Event.on_load(handler)
    if _LIFECYCLE == 8 then
        error('Calling Event.on_load after on_init() or on_load() has run is a desync risk.', 2)
    end
    core_on_load(handler)
end
function Event.on_configuration_changed(handler)
    if _LIFECYCLE == 8 then
        error('Calling Event.on_configuration_changed after on_init() or on_load() has run is a desync risk.', 2)
    end
    core_on_configuration_changed(handler)
end
function Event.on_nth_tick(tick, handler)
    if _LIFECYCLE == 8 then
        error('Calling Event.on_nth_tick after on_init() or on_load() has run is a desync risk.', 2)
    end
    core_on_nth_tick(tick, handler)
end
function Event.generate_event_name(name)
    local event_id = generate_event_name()
    if _DEBUG then
        defines.events[name] = event_id 
    end
    return event_id
end
function Event.add_event_filter(event, filter)
    local current_filters = get_event_filter(event)
    if not current_filters then
        current_filters = { filter }
    else
        table.insert(current_filters, filter)
    end
    script.set_event_filter(event, current_filters)
end
return Event
