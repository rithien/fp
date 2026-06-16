local Event = require 'lib.event'
local Gui = require 'gui.init'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local TOOLS_BUTTON_NAME = 'tools_top_button'
local OPEN_ACTION = 'tools_top_button_click'
local WINDOW_NAME = 'tools_panel_window'
local CLOSE_ACTION = 'tools_panel_close'
local CELL_ACTION = 'tools_panel_cell_click'
local CELL_PREFIX = 'tools_panel_cell_'
local BUTTON_SPRITE = 'item/repair-pack'
local GRID_COLUMNS = 4
local LEGACY_BUTTON_NAMES = {
    'even_distribution_top_button',
    'auto_pipe_connectors_top_button',
    'circuit_highlight_top_button',
}
local Public = {}
local entries = {}
function Public.register(entry)
    assert(type(entry) == 'table', 'ToolsPanel.register: entry must be a table')
    for _, field in ipairs({ 'id', 'is_enabled', 'is_user_enabled', 'toggle_user',
        'sprite_on', 'sprite_off', 'tooltip_on', 'tooltip_off', 'toggled_on', 'toggled_off' }) do
        assert(entry[field] ~= nil, 'ToolsPanel.register: missing field "' .. field .. '"')
    end
    entries[#entries + 1] = entry
end
local function any_master_enabled()
    for _, e in ipairs(entries) do
        if e.is_enabled() then
            return true
        end
    end
    return false
end
local function find_entry(id)
    for _, e in ipairs(entries) do
        if e.id == id then
            return e
        end
    end
    return nil
end
local function apply_cell_visual(button, entry, on)
    button.sprite = on and entry.sprite_on or entry.sprite_off
    button.tooltip = { on and entry.tooltip_on or entry.tooltip_off }
end
local function destroy_window(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end
local function cleanup_legacy_buttons(player)
    if not player or not player.valid then return end
    for _, name in ipairs(LEGACY_BUTTON_NAMES) do
        Gui.destroy_if_exists(player.gui.top, name)
    end
end
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    cleanup_legacy_buttons(player) 
    if not any_master_enabled() then
        Gui.destroy_if_exists(player.gui.top, TOOLS_BUTTON_NAME)
        destroy_window(player)
        return
    end
    if Gui.get_top_element(player, TOOLS_BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = TOOLS_BUTTON_NAME,
        sprite = BUTTON_SPRITE,
        tooltip = { 'fp-tools-panel.button-tooltip' },
        tags = { action = OPEN_ACTION },
    })
end
local function build_window(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-tools-panel.window-title' },
        style = 'frame_title',
        ignored_by_interaction = true,
    })
    local dragger = titlebar.add({
        type = 'empty-widget',
        style = 'draggable_space_header',
    })
    dragger.style.horizontally_stretchable = true
    dragger.style.vertically_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    Gui.add(titlebar, {
        type = 'sprite-button',
        sprite = 'utility/close',
        style = 'frame_action_button',
        tooltip = { 'fp-tools-panel.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    inside.style.padding = 12
    local grid = inside.add({ type = 'table', column_count = GRID_COLUMNS })
    grid.style.horizontal_spacing = 4
    grid.style.vertical_spacing = 4
    for _, e in ipairs(entries) do
        if e.is_enabled() then
            local on = e.is_user_enabled(player.index)
            local cell = Gui.add(grid, {
                type = 'sprite-button',
                name = CELL_PREFIX .. e.id,
                tags = { action = CELL_ACTION, id = e.id },
            })
            apply_cell_visual(cell, e, on)
        end
    end
    frame.force_auto_center()
    player.opened = frame
end
local function toggle_window(player)
    if not player or not player.valid then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        existing.destroy()
    else
        build_window(player)
    end
end
function Public.refresh(player)
    if not player or not player.valid then return end
    ensure_button(player)
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        build_window(player) 
    end
end
Gui.on_click(OPEN_ACTION, function(_, player)
    if not player or not player.valid then return end
    toggle_window(player)
end)
Gui.on_click(CLOSE_ACTION, function(_, player)
    destroy_window(player)
end)
Gui.on_click(CELL_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    if not element or not element.valid then return end
    local entry = find_entry(element.tags.id)
    if not entry then return end
    if not entry.is_enabled() then return end 
    local now_on = entry.toggle_user(player.index)
    apply_cell_visual(element, entry, now_on) 
    player.print({ now_on and entry.toggled_on or entry.toggled_off })
end)
Event.add(de.on_gui_closed, function(event)
    if event.element and event.element.valid and event.element.name == WINDOW_NAME then
        event.element.destroy()
    end
end)
TopButtons.register(ensure_button)
Event.add(de.on_player_joined_game, function(event)
    ensure_button(game.get_player(event.player_index))
end)
Event.on_configuration_changed(function()
    for _, p in pairs(game.connected_players) do
        Gui.destroy_if_exists(p.gui.top, TOOLS_BUTTON_NAME)
        ensure_button(p) 
    end
end)
return Public
