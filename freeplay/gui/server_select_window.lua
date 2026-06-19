local Event = require 'lib.event'
local Gui = require 'gui.init'
local ServerSelect = require 'lib.server_select'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'fp_server_select_button'
local WINDOW_NAME = 'fp_server_select_window'
local TOGGLE_ACTION = 'fp_server_select_toggle'
local CLOSE_ACTION = 'fp_server_select_close'
local CONNECT_ACTION = 'fp_server_select_connect'
local Public = {}
local function ensure_button(player)
    if not player or not player.valid then
        return
    end
    if Gui.get_top_element(player, BUTTON_NAME) then
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = 'utility/surface_editor_icon',
        tooltip = { 'fp-server-select.button-tooltip' },
        tags = { action = TOGGLE_ACTION }
    })
end
local function destroy_window(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end
local function build_window(player)
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical'
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-server-select.window-title' },
        style = 'frame_title',
        ignored_by_interaction = true
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
        tooltip = { 'fp-server-select.close' },
        tags = { action = CLOSE_ACTION }
    })
    local inside = frame.add({ type = 'frame', style = 'inside_shallow_frame', direction = 'vertical' })
    inside.style.padding = 12
    local servers = ServerSelect.get_servers()
    local current_id = ServerSelect.get_current_id()
    if #servers == 0 then
        inside.add({ type = 'label', caption = { 'fp-server-select.empty' } })
    else
        local scroll = inside.add({
            type = 'scroll-pane',
            direction = 'vertical',
            horizontal_scroll_policy = 'never',
            vertical_scroll_policy = 'auto'
        })
        scroll.style.maximal_height = 500
        scroll.style.minimal_width = 260
        for _, srv in ipairs(servers) do
            local is_current = (srv.id == current_id)
            local connectable = srv.public_address ~= nil and srv.game_port ~= nil
            local def = {
                type = 'button',
                caption = srv.name,
                tags = { action = CONNECT_ACTION, server_id = srv.id }
            }
            if is_current then
                def.style = 'confirm_button'
                def.enabled = false
                def.tooltip = { 'fp-server-select.you-are-here' }
            elseif not connectable then
                def.enabled = false
            end
            local btn = Gui.add(scroll, def)
            btn.style.horizontally_stretchable = true
            btn.style.horizontal_align = 'left'
        end
    end
    player.opened = frame
end
function Public.toggle(player)
    if not player or not player.valid then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        destroy_window(player)
    else
        build_window(player)
    end
end
local function refresh_open_windows()
    for _, player in pairs(game.connected_players) do
        local win = player.gui.screen[WINDOW_NAME]
        if win and win.valid then
            build_window(player)
        end
    end
end
ServerSelect.register_refresh(refresh_open_windows)
Gui.on_click(TOGGLE_ACTION, function(_, player)
    Public.toggle(player)
end)
Gui.on_click(CLOSE_ACTION, function(_, player)
    destroy_window(player)
end)
Gui.on_click(CONNECT_ACTION, function(event, player)
    if not player or not player.valid then return end
    local server_id = event.element.tags.server_id
    local srv = ServerSelect.get_server(server_id)
    if not srv then return end
    if srv.public_address and srv.game_port then
        destroy_window(player)
        player.connect_to_server({
            address = srv.public_address .. ':' .. srv.game_port,
            name = srv.name
        })
    end
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
        Gui.destroy_if_exists(p.gui.top, BUTTON_NAME)
        ensure_button(p)
    end
end)
return Public
