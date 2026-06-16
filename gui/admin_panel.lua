local Event = require 'lib.event'
local Gui = require 'gui.init'
local Config = require 'lib.config'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local TOGGLE_BUTTON_NAME = 'admin_panel_toggle_button'
local PANEL_FRAME_NAME = 'admin_panel_frame'
local TOGGLE_BUTTON_ACTION = 'admin_panel_toggle'
local CLOSE_ACTION = 'admin_panel_close'
local Public = {}
local toggles = {}   
local actions = {}   
local sliders = {}   
local dropdowns = {} 
local function toggle_action_name(id)
    return 'admin_panel_toggle_' .. id
end
local function action_action_name(id)
    return 'admin_panel_action_' .. id
end
local function slider_action_name(id)
    return 'admin_panel_slider_' .. id
end
local function slider_value_label_name(id)
    return 'admin_panel_slider_value_' .. id
end
local function dropdown_action_name(id)
    return 'admin_panel_dropdown_' .. id
end
local function dropdown_preview_name(id)
    return 'admin_panel_dropdown_preview_' .. id
end
function Public.register_toggle(def)
    assert(type(def) == 'table', 'admin_panel.register_toggle: def must be a table')
    assert(type(def.id) == 'string' and def.id ~= '', 'admin_panel toggle requires .id (string)')
    assert(type(def.caption) == 'string' or type(def.caption) == 'table', 'admin_panel toggle requires .caption (string or LocalisedString)')
    assert(type(def.get_state) == 'function', 'admin_panel toggle requires .get_state (function)')
    assert(type(def.on_change) == 'function', 'admin_panel toggle requires .on_change (function)')
    table.insert(toggles, def)
    Gui.on_switch_state_changed(toggle_action_name(def.id), function(event, player)
        if not player or not player.valid or not player.admin then
            return
        end
        local element = event.element
        if not element or not element.valid then
            return
        end
        local new_state = element.switch_state == 'right'
        def.on_change(new_state, player)
    end)
end
function Public.register_action(def)
    assert(type(def) == 'table', 'admin_panel.register_action: def must be a table')
    assert(type(def.id) == 'string' and def.id ~= '', 'admin_panel action requires .id (string)')
    assert(type(def.caption) == 'string' or type(def.caption) == 'table', 'admin_panel action requires .caption (string or LocalisedString)')
    assert(type(def.on_click) == 'function', 'admin_panel action requires .on_click (function)')
    table.insert(actions, def)
    Gui.on_click(action_action_name(def.id), function(_, player)
        if not player or not player.valid or not player.admin then
            return
        end
        def.on_click(player)
    end)
end
function Public.register_slider(def)
    assert(type(def) == 'table', 'admin_panel.register_slider: def must be a table')
    assert(type(def.id) == 'string' and def.id ~= '', 'admin_panel slider requires .id (string)')
    assert(type(def.caption) == 'string' or type(def.caption) == 'table', 'admin_panel slider requires .caption (string or LocalisedString)')
    assert(type(def.get_value) == 'function', 'admin_panel slider requires .get_value (function)')
    assert(type(def.on_change) == 'function', 'admin_panel slider requires .on_change (function)')
    def.min = def.min or 0
    def.max = def.max or 1
    def.step = def.step or 0.1
    def.format = def.format or function(v) return string.format('%.1f', v) end
    table.insert(sliders, def)
    Gui.on_value_changed(slider_action_name(def.id), function(event, player)
        if not player or not player.valid or not player.admin then
            return
        end
        local element = event.element
        if not element or not element.valid then
            return
        end
        local value = element.slider_value
        def.on_change(value, player)
        local row = element.parent
        if row and row.valid then
            local vlabel = row[slider_value_label_name(def.id)]
            if vlabel and vlabel.valid then
                vlabel.caption = def.format(value)
            end
        end
    end)
end
function Public.register_dropdown(def)
    assert(type(def) == 'table', 'admin_panel.register_dropdown: def must be a table')
    assert(type(def.id) == 'string' and def.id ~= '', 'admin_panel dropdown requires .id (string)')
    assert(type(def.caption) == 'string' or type(def.caption) == 'table', 'admin_panel dropdown requires .caption (string or LocalisedString)')
    assert(type(def.choices) == 'table' and #def.choices > 0, 'admin_panel dropdown requires non-empty .choices')
    assert(type(def.get_value) == 'function', 'admin_panel dropdown requires .get_value (function)')
    assert(type(def.on_change) == 'function', 'admin_panel dropdown requires .on_change (function)')
    table.insert(dropdowns, def)
    Gui.on_selection_state_changed(dropdown_action_name(def.id), function(event, player)
        if not player or not player.valid or not player.admin then
            return
        end
        local element = event.element
        if not element or not element.valid then
            return
        end
        local choice = def.choices[element.selected_index]
        if not choice then
            return
        end
        def.on_change(choice.key, player)
        if def.preview_color then
            local row = element.parent
            if row and row.valid then
                local preview = row[dropdown_preview_name(def.id)]
                if preview and preview.valid then
                    local rgb = def.preview_color(choice.key)
                    if rgb then preview.style.font_color = rgb end
                end
            end
        end
    end)
end
local function ensure_toggle_button(player)
    if not player or not player.valid then
        return
    end
    if not player.admin then
        Gui.destroy_if_exists(player.gui.top, TOGGLE_BUTTON_NAME)
        Gui.destroy_if_exists(player.gui.screen, PANEL_FRAME_NAME)
        return
    end
    if Gui.get_top_element(player, TOGGLE_BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = TOGGLE_BUTTON_NAME,
        sprite = 'utility/side_menu_menu_icon',
        tooltip = { 'fp-admin.button-tooltip' },
        tags = { action = TOGGLE_BUTTON_ACTION }
    })
end
local function make_tab_scroll_pane(tabbed_pane)
    local scroll = tabbed_pane.add({
        type = 'scroll-pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto'
    })
    scroll.style.maximal_height = 500
    scroll.style.minimal_width = 320
    scroll.style.padding = 8
    return scroll
end
local function build_toggles_into(parent)
    if #toggles == 0 then
        parent.add({
            type = 'label',
            caption = { 'fp-admin.placeholder-no-toggles' }
        })
        return
    end
    for _, t in ipairs(toggles) do
        local row = parent.add({ type = 'flow', direction = 'horizontal' })
        row.style.vertical_align = 'center'
        row.style.top_padding = 2
        row.style.bottom_padding = 2
        local ok, state = pcall(t.get_state)
        if not ok then
            state = false
        end
        local switch_state = state and 'right' or 'left'
        Gui.add(row, {
            type = 'switch',
            switch_state = switch_state,
            left_label_caption = { 'fp-admin.off' },
            right_label_caption = { 'fp-admin.on' },
            tooltip = t.tooltip or t.caption,
            tags = { action = toggle_action_name(t.id) }
        })
        local label = row.add({ type = 'label', caption = t.caption })
        label.style.left_padding = 8
    end
end
local function build_actions_into(parent)
    if #actions == 0 then
        parent.add({
            type = 'label',
            caption = { 'fp-admin.placeholder-no-actions' }
        })
        return
    end
    for _, a in ipairs(actions) do
        local btn = Gui.add(parent, {
            type = 'button',
            caption = a.caption,
            tooltip = a.tooltip,
            tags = { action = action_action_name(a.id) }
        })
        btn.style.horizontally_stretchable = true
        btn.style.minimal_width = 220
        btn.style.top_margin = 2
    end
end
local function build_sliders_into(parent)
    if #sliders == 0 then
        parent.add({
            type = 'label',
            caption = { 'fp-admin.placeholder-no-sliders' }
        })
        return
    end
    for _, s in ipairs(sliders) do
        local row = parent.add({ type = 'flow', direction = 'horizontal' })
        row.style.vertical_align = 'center'
        row.style.top_padding = 2
        row.style.bottom_padding = 2
        local label = row.add({ type = 'label', caption = s.caption, tooltip = s.tooltip })
        label.style.minimal_width = 150
        local ok, val = pcall(s.get_value)
        if not ok or type(val) ~= 'number' then
            val = s.min
        end
        local slider = Gui.add(row, {
            type = 'slider',
            minimum_value = s.min,
            maximum_value = s.max,
            value = val,
            value_step = s.step,
            discrete_slider = true,
            discrete_values = true,
            tooltip = s.tooltip,
            tags = { action = slider_action_name(s.id) }
        })
        slider.style.minimal_width = 160
        local vlabel = row.add({
            type = 'label',
            name = slider_value_label_name(s.id),
            caption = s.format(val)
        })
        vlabel.style.left_padding = 8
        vlabel.style.minimal_width = 44
    end
end
local function build_dropdowns_into(parent)
    if #dropdowns == 0 then
        parent.add({
            type = 'label',
            caption = { 'fp-admin.placeholder-no-dropdowns' }
        })
        return
    end
    for _, d in ipairs(dropdowns) do
        local row = parent.add({ type = 'flow', direction = 'horizontal' })
        row.style.vertical_align = 'center'
        row.style.top_padding = 2
        row.style.bottom_padding = 2
        local label = row.add({ type = 'label', caption = d.caption, tooltip = d.tooltip })
        label.style.minimal_width = 150
        local ok, current = pcall(d.get_value)
        if not ok then current = nil end
        local items, selected = {}, 1
        for i, c in ipairs(d.choices) do
            items[i] = c.caption
            if c.key == current then selected = i end
        end
        Gui.add(row, {
            type = 'drop-down',
            items = items,
            selected_index = selected,
            tooltip = d.tooltip,
            tags = { action = dropdown_action_name(d.id) }
        })
        if d.preview_color then
            local preview = row.add({
                type = 'label',
                name = dropdown_preview_name(d.id),
                caption = { 'fp-admin.preview-sample' }
            })
            preview.style.left_padding = 8
            local rgb = d.preview_color(current)
            if rgb then preview.style.font_color = rgb end
        end
    end
end
local function build_panel(player)
    Gui.destroy_if_exists(player.gui.screen, PANEL_FRAME_NAME)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = PANEL_FRAME_NAME,
        direction = 'vertical'
    })
    frame.auto_center = true
    local titlebar = frame.add({
        type = 'flow',
        direction = 'horizontal'
    })
    titlebar.add({
        type = 'label',
        caption = { 'fp-admin.panel-title' },
        style = 'frame_title'
    }).drag_target = frame
    local dragger = titlebar.add({
        type = 'empty-widget',
        style = 'draggable_space_header'
    })
    dragger.style.horizontally_stretchable = true
    dragger.style.vertically_stretchable = true
    dragger.style.height = 24
    dragger.drag_target = frame
    Gui.add(titlebar, {
        type = 'sprite-button',
        sprite = 'utility/close',
        style = 'frame_action_button',
        tooltip = { 'fp-admin.close-tooltip' },
        tags = { action = CLOSE_ACTION }
    })
    local tabbed_pane = frame.add({ type = 'tabbed-pane' })
    local toggles_tab = tabbed_pane.add({ type = 'tab', caption = { 'fp-admin.tab-toggles' } })
    local toggles_scroll = make_tab_scroll_pane(tabbed_pane)
    build_toggles_into(toggles_scroll)
    tabbed_pane.add_tab(toggles_tab, toggles_scroll)
    local sliders_tab = tabbed_pane.add({ type = 'tab', caption = { 'fp-admin.tab-sliders' } })
    local sliders_scroll = make_tab_scroll_pane(tabbed_pane)
    build_sliders_into(sliders_scroll)
    tabbed_pane.add_tab(sliders_tab, sliders_scroll)
    local dropdowns_tab = tabbed_pane.add({ type = 'tab', caption = { 'fp-admin.tab-dropdowns' } })
    local dropdowns_scroll = make_tab_scroll_pane(tabbed_pane)
    build_dropdowns_into(dropdowns_scroll)
    tabbed_pane.add_tab(dropdowns_tab, dropdowns_scroll)
    local actions_tab = tabbed_pane.add({ type = 'tab', caption = { 'fp-admin.tab-actions' } })
    local actions_scroll = make_tab_scroll_pane(tabbed_pane)
    build_actions_into(actions_scroll)
    tabbed_pane.add_tab(actions_tab, actions_scroll)
    tabbed_pane.selected_tab_index = 1
    player.opened = frame
end
function Public.refresh_open_panel(player)
    if not player or not player.valid then return end
    local existing = player.gui.screen[PANEL_FRAME_NAME]
    if existing and existing.valid then
        build_panel(player)
    end
end
Gui.on_click(TOGGLE_BUTTON_ACTION, function(_, player)
    if not player or not player.valid then
        return
    end
    if not player.admin then
        player.print({ 'fp-admin.admin-only' })
        return
    end
    local existing = player.gui.screen[PANEL_FRAME_NAME]
    if existing and existing.valid then
        existing.destroy()
    else
        build_panel(player)
    end
end)
Gui.on_click(CLOSE_ACTION, function(_, player)
    if not player or not player.valid then
        return
    end
    Gui.destroy_if_exists(player.gui.screen, PANEL_FRAME_NAME)
end)
Event.add(de.on_gui_closed, function(event)
    local element = event.element
    if not element or not element.valid then
        return
    end
    if element.name == PANEL_FRAME_NAME then
        element.destroy()
    end
end)
TopButtons.register(ensure_toggle_button)
Event.add(de.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    ensure_toggle_button(player)
end)
Event.add(de.on_player_promoted, function(event)
    local player = game.get_player(event.player_index)
    ensure_toggle_button(player)
end)
Event.add(de.on_player_demoted, function(event)
    local player = game.get_player(event.player_index)
    ensure_toggle_button(player)
end)
Event.on_configuration_changed(function()
    for _, player in pairs(game.connected_players) do
        if player.admin then
            Gui.destroy_if_exists(player.gui.top, TOGGLE_BUTTON_NAME)
            ensure_toggle_button(player)
        end
    end
end)
local function apply_config_defaults()
    Config.reset_to_defaults()
    local cfg_ids = {}
    for cfg_id, _ in Config.iter_defaults() do cfg_ids[cfg_id] = true end
    for _, def in ipairs(toggles) do
        if not cfg_ids[def.id] then
            log(string.format('[config] toggle "%s" zarejestrowany ale brak wpisu w scenario/toggle_defaults.lua — używam false', def.id))
        end
        if type(def.apply) == 'function' then
            local state = Config.is_enabled(def.id)
            local ok, err = pcall(def.apply, state)
            if not ok then
                log(string.format('[config] apply(%s, %s) failed: %s', def.id, tostring(state), tostring(err)))
            end
        end
    end
end
Event.on_init(apply_config_defaults)
Event.on_configuration_changed(apply_config_defaults)
return Public
