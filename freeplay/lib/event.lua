local EventCore = require 'lib.event_core'
local core_add = EventCore.add
local core_on_init = EventCore.on_init
local core_on_load = EventCore.on_load
local core_on_nth_tick = EventCore.on_nth_tick
local core_on_configuration_changed = EventCore.on_configuration_changed
local raise_event = script.raise_event
local generate_event_name = script.generate_event_name
local Event = {}
local function assert_registration_allowed(what)
    if (_LIFECYCLE or 0) >= 7 then
        error('Calling ' .. what .. ' during/after on_configuration_changed or at runtime is a desync risk.', 3)
    end
end
function Event.add(event_name, handler)
    assert_registration_allowed('Event.add')
    core_add(event_name, handler)
end
function Event.on_init(handler)
    assert_registration_allowed('Event.on_init')
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
    assert_registration_allowed('Event.on_load')
    core_on_load(handler)
end
function Event.on_configuration_changed(handler)
    assert_registration_allowed('Event.on_configuration_changed')
    core_on_configuration_changed(handler)
end
function Event.on_nth_tick(tick, handler)
    assert_registration_allowed('Event.on_nth_tick')
    core_on_nth_tick(tick, handler)
end
function Event.generate_event_name(name)
    local event_id = generate_event_name()
    if _DEBUG then
        defines.events[name] = event_id 
    end
    return event_id
end
return Event
