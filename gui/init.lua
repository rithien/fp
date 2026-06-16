local Event = require 'lib.event'
local de = defines.events
local Gui = {}
local handlers = {
    on_click = {},
    on_value_changed = {},
    on_text_changed = {},
    on_selection_state_changed = {},
    on_checked_state_changed = {},
    on_switch_state_changed = {},
    on_confirmed = {}
}
local function make_dispatcher(map_name)
    local map = handlers[map_name]
    return function(event)
        local element = event.element
        if not element or not element.valid then
            return
        end
        local tags = element.tags
        if not tags then
            return
        end
        local action = tags.action
        if not action then
            return
        end
        local handler = map[action]
        if not handler then
            return
        end
        local player
        if event.player_index then
            player = game.get_player(event.player_index)
        end
        handler(event, player)
    end
end
Event.add(de.on_gui_click, make_dispatcher('on_click'))
Event.add(de.on_gui_value_changed, make_dispatcher('on_value_changed'))
Event.add(de.on_gui_text_changed, make_dispatcher('on_text_changed'))
Event.add(de.on_gui_selection_state_changed, make_dispatcher('on_selection_state_changed'))
Event.add(de.on_gui_checked_state_changed, make_dispatcher('on_checked_state_changed'))
Event.add(de.on_gui_switch_state_changed, make_dispatcher('on_switch_state_changed'))
Event.add(de.on_gui_confirmed, make_dispatcher('on_confirmed'))
function Gui.add(parent, def)
    if not def.tags or not def.tags.action then
        error('Gui.add: def.tags.action (string) is required', 2)
    end
    return parent.add(def)
end
function Gui.on_click(action, handler)
    handlers.on_click[action] = handler
end
function Gui.on_value_changed(action, handler)
    handlers.on_value_changed[action] = handler
end
function Gui.on_text_changed(action, handler)
    handlers.on_text_changed[action] = handler
end
function Gui.on_selection_state_changed(action, handler)
    handlers.on_selection_state_changed[action] = handler
end
function Gui.on_checked_state_changed(action, handler)
    handlers.on_checked_state_changed[action] = handler
end
function Gui.on_switch_state_changed(action, handler)
    handlers.on_switch_state_changed[action] = handler
end
function Gui.on_confirmed(action, handler)
    handlers.on_confirmed[action] = handler
end
function Gui.destroy_if_exists(parent, name)
    if not parent or not parent.valid then
        return
    end
    local child = parent[name]
    if child and child.valid then
        child.destroy()
    end
end
function Gui.get_top_element(player, name)
    if not player or not player.valid then
        return nil
    end
    local top = player.gui.top
    local element = top[name]
    if element and element.valid then
        return element
    end
    return nil
end
return Gui
