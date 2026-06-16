local Event = require 'lib.event'
local Gui = require 'gui.init'
local Antigrief = require 'lib.antigrief'
local Jail = require 'lib.jail'
local Session = require 'lib.sessions'
local TopButtons = require 'gui.top_buttons'
local Constants = require 'constants'
local AUDIT = Constants.audit 
local de = defines.events
local TOGGLE_BUTTON_NAME = 'antigrief_toggle_button'
local PANEL_FRAME_NAME = 'antigrief_panel'
local TOGGLE_ACTION = 'antigrief_toggle_panel'
local CLOSE_ACTION = 'antigrief_close'
local ENABLED_SWITCH_ACTION = 'antigrief_set_enabled'
local PUNISH_MODE_SWITCH_ACTION = 'antigrief_set_punish_mode'
local ADMIN_TEMP_TRUST_SWITCH_ACTION = 'antigrief_set_admin_temp_trust'
local PLAYERS_FILTER_ACTION = 'antigrief_players_filter'
local PLAYERS_DROPDOWN_ACTION = 'antigrief_players_select'
local PLAYERS_BAN_ACTION = 'antigrief_players_ban'
local PLAYERS_UNBAN_ACTION = 'antigrief_players_unban'
local PLAYERS_JAIL_ACTION = 'antigrief_players_jail'
local PLAYERS_UNJAIL_ACTION = 'antigrief_players_unjail'
local PLAYERS_TRUST_ACTION = 'antigrief_players_trust'
local PLAYERS_UNTRUST_ACTION = 'antigrief_players_untrust'
local PLAYERS_ADMIN_ACTION = 'antigrief_players_admin'
local PLAYERS_DROPDOWN_NAME = 'antigrief_players_dropdown'
local PLAYERS_FILTER_SWITCH_NAME = 'antigrief_players_filter_switch'
local PLAYERS_INFO_LABEL_NAME = 'antigrief_players_info_label'
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
        sprite = 'utility/danger_icon',
        tooltip = { 'fp-antigrief-panel.players-button-tooltip' },
        tags = { action = TOGGLE_ACTION }
    })
end
local function find_by_name(parent, name)
    if not parent or not parent.valid then return nil end
    if parent.name == name then return parent end
    for _, child in pairs(parent.children) do
        local found = find_by_name(child, name)
        if found then return found end
    end
    return nil
end
local function get_player_list(filter_mode)
    local names = {}
    if filter_mode == 'online' then
        for _, p in pairs(game.connected_players) do
            table.insert(names, p.name)
        end
    else
        local online_set = {}
        for _, p in pairs(game.connected_players) do
            online_set[p.name] = true
        end
        for _, p in pairs(game.players) do
            if not online_set[p.name] then
                table.insert(names, p.name)
            end
        end
    end
    table.sort(names)
    return names
end
local function ensure_banned()
    if not storage.banned then storage.banned = {} end
    return storage.banned
end
local function is_banned(player_name)
    if not player_name or player_name == '' then return false end
    local b = storage.banned
    return b ~= nil and b[player_name] == true
end
local function val_loc(val)
    if val == nil then return { 'fp-antigrief-panel.val-unknown' } end
    return { val and 'fp-antigrief-panel.val-yes' or 'fp-antigrief-panel.val-no' }
end
local function build_player_info(player_name)
    if not player_name or player_name == '' then
        return { 'fp-antigrief-panel.info-none' }
    end
    local p = game.get_player(player_name)
    local banned_loc = val_loc(is_banned(player_name))
    local jailed_loc = val_loc(Jail.is_jailed(player_name))
    if not p then
        return { '',
            { 'fp-antigrief-panel.info-selected', player_name }, '\n',
            { 'fp-antigrief-panel.info-stats', val_loc(nil), val_loc(nil), val_loc(nil) }, '\n',
            { 'fp-antigrief-panel.info-banned', banned_loc }, '\n',
            { 'fp-antigrief-panel.info-jailed', jailed_loc } }
    end
    return { '',
        { 'fp-antigrief-panel.info-selected', p.name }, '\n',
        { 'fp-antigrief-panel.info-stats',
            val_loc(p.connected),
            val_loc(Session.get_trusted_player(p) and true or false),
            val_loc(p.admin) }, '\n',
        { 'fp-antigrief-panel.info-banned', banned_loc }, '\n',
        { 'fp-antigrief-panel.info-jailed', jailed_loc } }
end
local function get_selected_player_name(admin_player)
    local frame = admin_player.gui.screen[PANEL_FRAME_NAME]
    if not frame or not frame.valid then return nil end
    local dropdown = find_by_name(frame, PLAYERS_DROPDOWN_NAME)
    if not dropdown or not dropdown.valid then return nil end
    local idx = dropdown.selected_index
    if idx <= 0 then return nil end
    return dropdown.items[idx]
end
local function refresh_players_tab(admin_player)
    if not admin_player or not admin_player.valid then return end
    local frame = admin_player.gui.screen[PANEL_FRAME_NAME]
    if not frame or not frame.valid then return end
    local switch = find_by_name(frame, PLAYERS_FILTER_SWITCH_NAME)
    local dropdown = find_by_name(frame, PLAYERS_DROPDOWN_NAME)
    local info_label = find_by_name(frame, PLAYERS_INFO_LABEL_NAME)
    if not (switch and dropdown and info_label) then return end
    local filter = switch.switch_state == 'left' and 'online' or 'offline'
    local names = get_player_list(filter)
    dropdown.items = names
    dropdown.selected_index = (#names > 0) and 1 or 0
    info_label.caption = build_player_info(names[1] or '')
end
local function refresh_player_info(admin_player)
    if not admin_player or not admin_player.valid then return end
    local frame = admin_player.gui.screen[PANEL_FRAME_NAME]
    if not frame or not frame.valid then return end
    local dropdown = find_by_name(frame, PLAYERS_DROPDOWN_NAME)
    local info_label = find_by_name(frame, PLAYERS_INFO_LABEL_NAME)
    if not (dropdown and info_label) then return end
    local idx = dropdown.selected_index
    local name = (idx > 0) and dropdown.items[idx] or ''
    info_label.caption = build_player_info(name)
end
local function build_players_content(parent)
    local content = parent.add({ type = 'flow', direction = 'vertical' })
    content.style.padding = 8
    content.style.minimal_width = 600
    content.style.minimal_height = 400
    local filter_row = content.add({ type = 'flow', direction = 'horizontal' })
    filter_row.style.vertical_align = 'center'
    filter_row.style.bottom_padding = 8
    local show_label = filter_row.add({ type = 'label', caption = { 'fp-antigrief-panel.show-label' } })
    show_label.style.right_padding = 6
    Gui.add(filter_row, {
        type = 'switch',
        name = PLAYERS_FILTER_SWITCH_NAME,
        switch_state = 'left', 
        left_label_caption = { 'fp-antigrief-panel.filter-online' },
        right_label_caption = { 'fp-antigrief-panel.filter-offline' },
        tooltip = { 'fp-antigrief-panel.filter-tooltip' },
        tags = { action = PLAYERS_FILTER_ACTION }
    })
    local picker_label = filter_row.add({ type = 'label', caption = { 'fp-antigrief-panel.player-label' } })
    picker_label.style.left_padding = 12
    picker_label.style.right_padding = 6
    local names = get_player_list('online')
    local dropdown = Gui.add(filter_row, {
        type = 'drop-down',
        name = PLAYERS_DROPDOWN_NAME,
        items = names,
        selected_index = (#names > 0) and 1 or 0,
        tags = { action = PLAYERS_DROPDOWN_ACTION }
    })
    dropdown.style.minimal_width = 220
    local actions_row = content.add({ type = 'flow', direction = 'horizontal' })
    actions_row.style.bottom_padding = 8
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.ban-caption' },
        tooltip = { 'fp-antigrief-panel.ban-tooltip' },
        tags = { action = PLAYERS_BAN_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.unban-caption' },
        tooltip = { 'fp-antigrief-panel.unban-tooltip' },
        tags = { action = PLAYERS_UNBAN_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.jail-caption' },
        tooltip = { 'fp-antigrief-panel.jail-tooltip' },
        tags = { action = PLAYERS_JAIL_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.unjail-caption' },
        tooltip = { 'fp-antigrief-panel.unjail-tooltip' },
        tags = { action = PLAYERS_UNJAIL_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.trust-caption' },
        tooltip = { 'fp-antigrief-panel.trust-tooltip' },
        tags = { action = PLAYERS_TRUST_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.untrust-caption' },
        tooltip = { 'fp-antigrief-panel.untrust-tooltip' },
        tags = { action = PLAYERS_UNTRUST_ACTION }
    })
    Gui.add(actions_row, {
        type = 'button', caption = { 'fp-antigrief-panel.admin-caption' },
        tooltip = { 'fp-antigrief-panel.admin-tooltip' },
        tags = { action = PLAYERS_ADMIN_ACTION }
    })
    local info_label = content.add({
        type = 'label',
        name = PLAYERS_INFO_LABEL_NAME,
        caption = build_player_info(names[1] or '')
    })
    info_label.style.single_line = false
    info_label.style.top_padding = 4
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
        caption = { 'fp-antigrief-panel.panel-title' },
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
        tooltip = { 'fp-antigrief-panel.close-tooltip' },
        tags = { action = CLOSE_ACTION }
    })
    local function add_setting_row(parent, caption, tooltip, current_state, action, left_caption, right_caption)
        local row = parent.add({ type = 'flow', direction = 'horizontal' })
        row.style.vertical_align = 'center'
        row.style.top_padding = 4
        row.style.bottom_padding = 4
        local label = row.add({ type = 'label', caption = caption })
        label.style.minimal_width = 220
        label.style.right_padding = 8
        Gui.add(row, {
            type = 'switch',
            switch_state = current_state and 'right' or 'left',
            left_label_caption = left_caption or { 'fp-admin.off' },
            right_label_caption = right_caption or { 'fp-admin.on' },
            tooltip = tooltip,
            tags = { action = action }
        })
    end
    local enabled = Antigrief.get('enabled')
    add_setting_row(frame, { 'fp-antigrief-panel.enforcement-label' }, { 'fp-antigrief-panel.enforcement-tooltip' },
        enabled, ENABLED_SWITCH_ACTION)
    local punish_jail = Antigrief.get('punish_mode') == 'jail'
    add_setting_row(frame, { 'fp-antigrief-panel.auto-action-label' }, { 'fp-antigrief-panel.auto-action-tooltip' },
        punish_jail, PUNISH_MODE_SWITCH_ACTION,
        { 'fp-antigrief-panel.auto-action-ban' }, { 'fp-antigrief-panel.auto-action-jail' })
    local admin_temp_trust = Antigrief.get('admin_temp_trust')
    add_setting_row(frame, { 'fp-antigrief-panel.admin-temp-trust-label' }, { 'fp-antigrief-panel.admin-temp-trust-tooltip' },
        admin_temp_trust, ADMIN_TEMP_TRUST_SWITCH_ACTION)
    build_players_content(frame)
    player.opened = frame
end
Gui.on_click(TOGGLE_ACTION, function(_, player)
    if not player or not player.valid then
        return
    end
    if not player.admin then
        player.print({ 'fp-antigrief-panel.admin-only' })
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
Gui.on_switch_state_changed(ENABLED_SWITCH_ACTION, function(event, player)
    if not player or not player.valid or not player.admin then
        return
    end
    local element = event.element
    if not element or not element.valid then
        return
    end
    local new_enabled = element.switch_state == 'right'
    Antigrief.set_enabled(new_enabled)
    game.print({ 'fp-antigrief-panel.bc-enforcement',
                 { new_enabled and 'fp-admin.on' or 'fp-admin.off' }, player.name },
               { color = { r = 1, g = 1, b = 0 } })
end)
Gui.on_switch_state_changed(PUNISH_MODE_SWITCH_ACTION, function(event, player)
    if not player or not player.valid or not player.admin then
        return
    end
    local element = event.element
    if not element or not element.valid then
        return
    end
    local jail = element.switch_state == 'right'
    Antigrief.set('punish_mode', jail and 'jail' or 'ban')
    game.print({ 'fp-antigrief-panel.bc-auto-action',
                 { jail and 'fp-antigrief-panel.auto-action-jail' or 'fp-antigrief-panel.auto-action-ban' }, player.name },
               { color = { r = 1, g = 1, b = 0 } })
end)
Gui.on_switch_state_changed(ADMIN_TEMP_TRUST_SWITCH_ACTION, function(event, player)
    if not player or not player.valid or not player.admin then
        return
    end
    local element = event.element
    if not element or not element.valid then
        return
    end
    local on = element.switch_state == 'right'
    Antigrief.set_admin_temp_trust(on)
    game.print({ 'fp-antigrief-panel.bc-admin-temp-trust',
                 { on and 'fp-admin.on' or 'fp-admin.off' }, player.name },
               { color = { r = 1, g = 1, b = 0 } })
end)
Gui.on_switch_state_changed(PLAYERS_FILTER_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    refresh_players_tab(admin)
end)
Gui.on_selection_state_changed(PLAYERS_DROPDOWN_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    refresh_player_info(admin)
end)
Gui.on_click(PLAYERS_BAN_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    game.ban_player(name, string.format(AUDIT.banned_by, admin.name))
    ensure_banned()[name] = true 
    game.print({ 'fp-antigrief-panel.bc-banned', name, admin.name },
               { color = { r = 1, g = 1, b = 0 } })
    refresh_players_tab(admin)
end)
Gui.on_click(PLAYERS_UNBAN_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    game.unban_player(name)
    local b = storage.banned
    if b then b[name] = nil end 
    game.print({ 'fp-antigrief-panel.bc-unbanned', name, admin.name },
               { color = { r = 1, g = 1, b = 0 } })
    refresh_player_info(admin)
end)
Gui.on_click(PLAYERS_JAIL_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    Jail.jail_player(name, string.format(AUDIT.jailed_by, admin.name), admin.name)
    refresh_players_tab(admin)
end)
Gui.on_click(PLAYERS_UNJAIL_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    Jail.unjail_player(name)
    refresh_player_info(admin)
end)
Gui.on_click(PLAYERS_TRUST_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    local target = game.get_player(name)
    if not target then admin.print({ 'fp-antigrief-panel.err-player-not-found', name }) return end
    Event.raise(Session.events.on_player_trusted, { player_index = target.index }) 
    game.print({ 'fp-antigrief-panel.bc-trusted', name, admin.name },
               { color = { r = 1, g = 1, b = 0 } })
    refresh_player_info(admin)
end)
Gui.on_click(PLAYERS_UNTRUST_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    local target = game.get_player(name)
    if not target then admin.print({ 'fp-antigrief-panel.err-player-not-found', name }) return end
    Event.raise(Session.events.on_player_untrusted, { player_index = target.index }) 
    game.print({ 'fp-antigrief-panel.bc-untrusted', name, admin.name },
               { color = { r = 1, g = 1, b = 0 } })
    refresh_player_info(admin)
end)
Gui.on_click(PLAYERS_ADMIN_ACTION, function(_, admin)
    if not admin or not admin.valid or not admin.admin then return end
    local name = get_selected_player_name(admin)
    if not name then admin.print({ 'fp-antigrief-panel.err-no-selection' }) return end
    local target = game.get_player(name)
    if not target then admin.print({ 'fp-antigrief-panel.err-player-not-found', name }) return end
    target.admin = not target.admin
    game.print({ target.admin and 'fp-antigrief-panel.bc-promoted' or 'fp-antigrief-panel.bc-demoted', name, admin.name },
               { color = { r = 1, g = 1, b = 0 } })
    refresh_player_info(admin)
end)
Event.add(de.on_player_banned, function(event)
    if not event.player_name then return end
    ensure_banned()[event.player_name] = true
end)
Event.add(de.on_player_unbanned, function(event)
    if not event.player_name then return end
    local b = storage.banned
    if b then b[event.player_name] = nil end
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
