local Event = require 'lib.event'
local Gui = require 'gui.init'
local Config = require 'lib.config'
local Overhead = require 'lib.translation_overhead'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'locales_top_button'
local CLICK_ACTION = 'locales_top_button_click'
local WINDOW_NAME = 'locales_menu_window'
local CLOSE_ACTION = 'locales_menu_close'
local ENABLE_ACTION = 'locales_menu_enable'
local SCALE_ACTION = 'locales_menu_scale'
local SCALE_VALUE_LABEL = 'locales_menu_scale_value'
local COLOR_ACTION = 'locales_menu_color'
local COLOR_PREVIEW_NAME = 'locales_menu_color_preview'
local RESET_ACTION = 'locales_menu_reset'
local Public = {}
local COLOR_CAPTIONS = {
    white  = { 'fp-locales-menu.color-white' },
    yellow = { 'fp-locales-menu.color-yellow' },
    cyan   = { 'fp-locales-menu.color-cyan' },
    green  = { 'fp-locales-menu.color-green' },
    orange = { 'fp-locales-menu.color-orange' },
    pink   = { 'fp-locales-menu.color-pink' },
    red    = { 'fp-locales-menu.color-red' },
    black  = { 'fp-locales-menu.color-black' },
}
local function button_sprite()
    for _, path in ipairs({ 'virtual-signal/signal-L', 'utility/questionmark' }) do
        if helpers.is_valid_sprite_path(path) then return path end
    end
    return 'utility/side_menu_menu_icon'
end
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if not Config.is_enabled('translate_overhead') then
        Gui.destroy_if_exists(player.gui.top, BUTTON_NAME)
        Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
        return
    end
    if Gui.get_top_element(player, BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = button_sprite(),
        tooltip = { 'fp-locales-menu.button-tooltip' },
        tags = { action = CLICK_ACTION }
    })
end
local function open(player)
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
        caption = { 'fp-locales-menu.window-title' },
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
        tooltip = { 'fp-locales-menu.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    inside.style.padding = 12
    inside.style.minimal_width = 340
    Gui.add(inside, {
        type = 'checkbox',
        caption = { 'fp-locales-menu.enable-caption' },
        tooltip = { 'fp-locales-menu.enable-tooltip' },
        state = not Overhead.is_user_disabled(player.index),
        tags = { action = ENABLE_ACTION },
    }).style.bottom_margin = 8
    local srow = inside.add({ type = 'flow', direction = 'horizontal' })
    srow.style.vertical_align = 'center'
    srow.add({
        type = 'label',
        caption = { 'fp-locales-menu.size-caption' },
        tooltip = { 'fp-locales-menu.size-tooltip' },
    }).style.minimal_width = 90
    local min_scale, max_scale = Overhead.get_scale_bounds()
    local val = Overhead.effective_scale(player.index)
    if val < min_scale then val = min_scale elseif val > max_scale then val = max_scale end
    local slider = Gui.add(srow, {
        type = 'slider',
        minimum_value = min_scale,
        maximum_value = max_scale,
        value = val,
        value_step = 0.2,
        discrete_slider = true,
        discrete_values = true,
        tooltip = { 'fp-locales-menu.size-tooltip' },
        tags = { action = SCALE_ACTION },
    })
    slider.style.minimal_width = 160
    local vlabel = srow.add({
        type = 'label',
        name = SCALE_VALUE_LABEL,
        caption = string.format('%.1f', val),
    })
    vlabel.style.left_padding = 8
    local crow = inside.add({ type = 'flow', direction = 'horizontal' })
    crow.style.vertical_align = 'center'
    crow.style.top_padding = 4
    crow.add({
        type = 'label',
        caption = { 'fp-locales-menu.color-caption' },
        tooltip = { 'fp-locales-menu.color-tooltip' },
    }).style.minimal_width = 90
    local choices = Overhead.get_color_choices()
    local current = Overhead.get_user_color_key(player.index) or Overhead.get_color_key()
    local items, selected = {}, 1
    for i, c in ipairs(choices) do
        items[i] = COLOR_CAPTIONS[c.key] or c.caption
        if c.key == current then selected = i end
    end
    Gui.add(crow, {
        type = 'drop-down',
        items = items,
        selected_index = selected,
        tooltip = { 'fp-locales-menu.color-tooltip' },
        tags = { action = COLOR_ACTION },
    })
    local preview = crow.add({
        type = 'label',
        name = COLOR_PREVIEW_NAME,
        caption = { 'fp-locales-menu.preview-sample' },
    })
    preview.style.left_padding = 8
    local rgb = Overhead.get_color_rgb(current)
    if rgb then preview.style.font_color = rgb end
    local rrow = inside.add({ type = 'flow', direction = 'horizontal' })
    rrow.style.top_padding = 8
    Gui.add(rrow, {
        type = 'button',
        caption = { 'fp-locales-menu.reset-caption' },
        tooltip = { 'fp-locales-menu.reset-tooltip' },
        tags = { action = RESET_ACTION },
    })
    player.opened = frame
end
function Public.refresh(player)
    ensure_button(player)
end
Gui.on_click(CLICK_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not Config.is_enabled('translate_overhead') then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        existing.destroy()  
        return
    end
    open(player)
end)
Gui.on_click(CLOSE_ACTION, function(_, player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end)
Gui.on_checked_state_changed(ENABLE_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    if not element or not element.valid then return end
    Overhead.set_user_disabled(player.index, not element.state)
end)
Gui.on_value_changed(SCALE_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    if not element or not element.valid then return end
    Overhead.set_user_scale(player.index, element.slider_value)
    local row = element.parent
    if row and row.valid then
        local vlabel = row[SCALE_VALUE_LABEL]
        if vlabel and vlabel.valid then
            vlabel.caption = string.format('%.1f', element.slider_value)
        end
    end
end)
Gui.on_selection_state_changed(COLOR_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    if not element or not element.valid then return end
    local choice = Overhead.get_color_choices()[element.selected_index]
    if not choice then return end
    Overhead.set_user_color_key(player.index, choice.key)
    local row = element.parent
    if row and row.valid then
        local preview = row[COLOR_PREVIEW_NAME]
        if preview and preview.valid then
            local rgb = Overhead.get_color_rgb(choice.key)
            if rgb then preview.style.font_color = rgb end
        end
    end
end)
Gui.on_click(RESET_ACTION, function(_, player)
    if not player or not player.valid then return end
    Overhead.reset_user(player.index)
    open(player)  
end)
Event.add(de.on_gui_closed, function(event)
    local element = event.element
    if element and element.valid and element.name == WINDOW_NAME then
        element.destroy()
    end
end)
TopButtons.register(ensure_button)
Event.add(de.on_player_joined_game, function(event)
    ensure_button(game.get_player(event.player_index))
end)
Event.on_configuration_changed(function()
    for _, p in pairs(game.connected_players) do
        Gui.destroy_if_exists(p.gui.top, BUTTON_NAME)
        ensure_button(p)
    end
end)
return Public
