local Event = require 'lib.event'
local Gui = require 'gui.init'
local TurretFiller = require 'lib.turret_filler'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'turret_filler_top_button'
local CLICK_ACTION = 'turret_filler_top_button_click'
local WINDOW_NAME = 'turret_filler_window'
local CLOSE_ACTION = 'turret_filler_close'
local ENABLE_ACTION = 'turret_filler_enable'
local AMMO_ACTION = 'turret_filler_ammo'
local AMOUNT_SLIDER_ACTION = 'turret_filler_amount_slider'
local AMOUNT_FIELD_ACTION = 'turret_filler_amount_field'
local LOWER_ACTION = 'turret_filler_lower'
local AMOUNT_SLIDER_NAME = 'turret_filler_amount_slider'
local AMOUNT_FIELD_NAME = 'turret_filler_amount_field'
local LABEL_WIDTH = 110
local Public = {}
local function button_sprite()
    for _, path in ipairs({ 'item/firearm-magazine', 'utility/ammo_icon' }) do
        if helpers.is_valid_sprite_path(path) then return path end
    end
    return 'utility/side_menu_menu_icon'
end
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if not TurretFiller.is_enabled() then
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
        tooltip = { 'fp-turret-filler.button-tooltip' },
        tags = { action = CLICK_ACTION }
    })
end
local function displayed_ammo(player, names)
    local current = TurretFiller.get_settings(player.index).ammo
    for _, name in ipairs(names) do
        if name == current then return current end
    end
    return names[1]
end
local function open(player)
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
    local settings = TurretFiller.get_settings(player.index)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-turret-filler.window-title' },
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
        tooltip = { 'fp-turret-filler.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    inside.style.padding = 12
    inside.style.minimal_width = 340
    local description = inside.add({ type = 'label', caption = { 'fp-turret-filler.description' } })
    description.style.single_line = false
    description.style.maximal_width = 340
    description.style.bottom_margin = 8
    Gui.add(inside, {
        type = 'checkbox',
        caption = { 'fp-turret-filler.enable-caption' },
        tooltip = { 'fp-turret-filler.enable-tooltip' },
        state = settings.enabled,
        tags = { action = ENABLE_ACTION },
    }).style.bottom_margin = 8
    local arow = inside.add({ type = 'flow', direction = 'horizontal' })
    arow.style.vertical_align = 'center'
    arow.style.bottom_padding = 4
    arow.add({
        type = 'label',
        caption = { 'fp-turret-filler.ammo-caption' },
        tooltip = { 'fp-turret-filler.ammo-tooltip' },
    }).style.minimal_width = LABEL_WIDTH
    local names = TurretFiller.get_selectable_ammo(player)
    if #names > 0 then
        Gui.add(arow, {
            type = 'choose-elem-button',
            elem_type = 'item',
            item = displayed_ammo(player, names),
            elem_filters = { { filter = 'name', name = names } },
            tooltip = { 'fp-turret-filler.ammo-tooltip' },
            tags = { action = AMMO_ACTION },
        })
    else
        arow.add({ type = 'label', caption = { 'fp-turret-filler.no-ammo-available' } })
    end
    local min_amount, max_amount = TurretFiller.get_amount_bounds()
    local srow = inside.add({ type = 'flow', direction = 'horizontal' })
    srow.style.vertical_align = 'center'
    srow.add({
        type = 'label',
        caption = { 'fp-turret-filler.amount-caption' },
        tooltip = { 'fp-turret-filler.amount-tooltip' },
    }).style.minimal_width = LABEL_WIDTH
    local slider = Gui.add(srow, {
        type = 'slider',
        name = AMOUNT_SLIDER_NAME,
        minimum_value = min_amount,
        maximum_value = max_amount,
        value = settings.amount,
        value_step = 1,
        discrete_values = true,
        tooltip = { 'fp-turret-filler.amount-tooltip' },
        tags = { action = AMOUNT_SLIDER_ACTION },
    })
    slider.style.minimal_width = 160
    local field = Gui.add(srow, {
        type = 'textfield',
        name = AMOUNT_FIELD_NAME,
        text = tostring(settings.amount),
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        tooltip = { 'fp-turret-filler.amount-tooltip' },
        tags = { action = AMOUNT_FIELD_ACTION },
    })
    field.style.width = 50
    field.style.left_margin = 8
    Gui.add(inside, {
        type = 'checkbox',
        caption = { 'fp-turret-filler.lower-caption' },
        tooltip = { 'fp-turret-filler.lower-tooltip' },
        state = settings.lower_allowed,
        tags = { action = LOWER_ACTION },
    }).style.top_margin = 8
    player.opened = frame
end
function Public.refresh(player)
    ensure_button(player)
end
Gui.on_click(CLICK_ACTION, function(_, player)
    if not player or not player.valid then return end
    if not TurretFiller.is_enabled() then return end
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
    TurretFiller.set_user_enabled(player.index, event.element.state)
end)
Gui.on_checked_state_changed(LOWER_ACTION, function(event, player)
    if not player or not player.valid then return end
    TurretFiller.set_lower_allowed(player.index, event.element.state)
end)
Gui.on_elem_changed(AMMO_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    local value = element.elem_value
    TurretFiller.set_ammo(player.index, value)
    if not value then
        local names = TurretFiller.get_selectable_ammo(player)
        if #names > 0 then
            element.elem_value = displayed_ammo(player, names)
        end
    end
end)
Gui.on_value_changed(AMOUNT_SLIDER_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    local value = TurretFiller.set_amount(player.index, element.slider_value)
    local row = element.parent
    local field = row and row.valid and row[AMOUNT_FIELD_NAME]
    if field and field.valid then
        field.text = tostring(value)
    end
end)
Gui.on_text_changed(AMOUNT_FIELD_ACTION, function(event, player)
    if not player or not player.valid then return end
    local element = event.element
    local number = tonumber(element.text)
    local min_amount = TurretFiller.get_amount_bounds()
    if not number or number < min_amount then return end
    local value = TurretFiller.set_amount(player.index, number)
    if value ~= number then
        element.text = tostring(value)  
    end
    local row = element.parent
    local slider = row and row.valid and row[AMOUNT_SLIDER_NAME]
    if slider and slider.valid then
        slider.slider_value = value
    end
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
