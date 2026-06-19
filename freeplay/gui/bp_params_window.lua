local Event = require 'lib.event'
local Gui = require 'gui.init'
local BpParams = require 'lib.bp_params'
local WINDOW_NAME = 'bp_params_window'
local CLOSE_ACTION = 'bp_params_window_close'
local COPY_ACTION = 'bp_params_window_copy'
local SLOT_ACTIONS = {
    source = 'bp_params_window_slot_source',
    target = 'bp_params_window_slot_target',
}
local SLOT_BUTTON_NAMES = {
    source = 'bp_params_slot_button_source',
    target = 'bp_params_slot_button_target',
}
local SLOT_STATE_NAMES = {
    source = 'bp_params_slot_state_source',
    target = 'bp_params_slot_state_target',
}
local SLOT_LABEL_KEYS = {
    source = 'fp-bp-params.source-label',
    target = 'fp-bp-params.target-label',
}
local STATUS_LABEL_NAME = 'bp_params_status'
local INSIDE_NAME = 'bp_params_inside'
local EDIT_ACTIONS = {
    source = 'bp_params_window_edit_source',
    target = 'bp_params_window_edit_target',
}
local EDIT_BUTTON_NAMES = {
    source = 'bp_params_edit_button_source',
    target = 'bp_params_edit_button_target',
}
local EDITOR_NAME = 'bp_params_editor'
local EDITOR_SCROLL_NAME = 'bp_params_editor_scroll'
local EDITOR_RAW_NAME = 'bp_params_editor_raw'
local EDITOR_APPLY_ACTION = 'bp_params_editor_apply'
local EDITOR_CANCEL_ACTION = 'bp_params_editor_cancel'
local EDITOR_RAW_TOGGLE_ACTION = 'bp_params_editor_raw_toggle'
local COLOR_ERROR = { r = 1, g = 0.3, b = 0.3 }
local COLOR_SUCCESS = { r = 0.3, g = 1, b = 0.3 }
local BpParamsWindow = {}
local function find_descendant(root, name)
    if not root or not root.valid then return nil end
    local direct = root[name]
    if direct and direct.valid then return direct end
    for _, child in pairs(root.children) do
        local found = find_descendant(child, name)
        if found then return found end
    end
    return nil
end
local function get_window(player)
    local win = player and player.valid and player.gui.screen[WINDOW_NAME]
    if win and win.valid then return win end
    return nil
end
local function set_status(player, locale_key, color, count)
    local win = get_window(player)
    local label = win and find_descendant(win, STATUS_LABEL_NAME)
    if not label then return end
    if locale_key then
        label.caption = count and { locale_key, tostring(count) } or { locale_key }
        label.style.font_color = color or COLOR_ERROR
        label.visible = true
    else
        label.caption = ''
        label.visible = false
    end
end
local function refresh_slot(player, which)
    local win = get_window(player)
    if not win then return end
    local button = find_descendant(win, SLOT_BUTTON_NAMES[which])
    local state = find_descendant(win, SLOT_STATE_NAMES[which])
    if not button or not state then return end
    local snapshot = BpParams.get_slots(player.index)[which]
    if snapshot then
        button.sprite = 'item/blueprint'
        button.number = snapshot.param_count
        state.caption = {
            'fp-bp-params.slot-set',
            snapshot.label or { 'fp-bp-params.unnamed-blueprint' },
            tostring(snapshot.param_count),
        }
    else
        button.sprite = nil
        button.number = nil
        state.caption = { 'fp-bp-params.slot-empty' }
    end
    local edit = find_descendant(win, EDIT_BUTTON_NAMES[which])
    if edit then
        edit.enabled = snapshot ~= nil and snapshot.param_count > 0
    end
end
local function trim(s)
    return (s or ''):match('^%s*(.-)%s*$') or ''
end
local function give_result_to_cursor(player, result)
    if not player.clear_cursor() then
        set_status(player, 'fp-bp-params.cursor-busy')
        return false
    end
    local stack = player.cursor_stack
    if not stack or stack.import_stack(result) == 1 then
        set_status(player, 'fp-bp-params.import-error')
        return false
    end
    return true
end
local function destroy_editor(player)
    local win = get_window(player)
    if win then
        local editor = find_descendant(win, EDITOR_NAME)
        if editor and editor.valid then
            editor.destroy()
        end
    end
    local slots = BpParams.get_slots(player.index)
    slots.editing = nil
    slots.editing_raw = nil
end
local function params_to_json_lines(params)
    if #params == 0 then return '[]' end
    local lines = {}
    for i, p in ipairs(params) do
        lines[i] = '  ' .. helpers.table_to_json(p)
    end
    return '[\n' .. table.concat(lines, ',\n') .. '\n]'
end
local function add_editor_field(tbl, index, field, value, width)
    local tf = tbl.add({
        type = 'textfield',
        text = value ~= nil and tostring(value) or '',
        tags = { bp_edit_index = index, bp_edit_field = field },
    })
    tf.style.width = width
    return tf
end
local function add_editor_label(tbl, caption, bold)
    local label = tbl.add({ type = 'label', caption = caption })
    if bold then label.style.font = 'default-bold' end
    return label
end
local function open_editor(player, which, raw)
    local win = get_window(player)
    if not win then return end
    destroy_editor(player)
    local slots = BpParams.get_slots(player.index)
    local snapshot = slots[which]
    if not snapshot then return end
    local params, err = BpParams.get_parameters(snapshot.string)
    if not params then
        set_status(player, err)
        return
    end
    if #params == 0 then
        set_status(player, 'fp-bp-params.no-params')
        return
    end
    local inside = win[INSIDE_NAME]
    if not inside or not inside.valid then return end
    slots.editing = which
    slots.editing_raw = raw and true or nil
    local editor = inside.add({ type = 'flow', name = EDITOR_NAME, direction = 'vertical' })
    editor.style.top_margin = 8
    editor.add({ type = 'line' })
    local title = editor.add({
        type = 'label',
        caption = { 'fp-bp-params.editor-title', { SLOT_LABEL_KEYS[which] } },
    })
    title.style.font = 'default-bold'
    if raw then
        local textbox = editor.add({
            type = 'text-box',
            name = EDITOR_RAW_NAME,
            text = params_to_json_lines(params),
        })
        textbox.word_wrap = true
        textbox.style.width = 460
        textbox.style.minimal_height = 220
        textbox.style.maximal_height = 340
    else
        local scroll = editor.add({ type = 'scroll-pane', name = EDITOR_SCROLL_NAME })
        scroll.style.maximal_height = 320
        local tbl = scroll.add({ type = 'table', column_count = 5 })
        tbl.style.horizontal_spacing = 6
        tbl.style.vertical_spacing = 4
        add_editor_label(tbl, '', true)
        add_editor_label(tbl, { 'fp-bp-params.col-name' }, true)
        add_editor_label(tbl, { 'fp-bp-params.col-number' }, true)
        add_editor_label(tbl, { 'fp-bp-params.col-variable' }, true)
        add_editor_label(tbl, { 'fp-bp-params.col-formula' }, true)
        for i, p in ipairs(params) do
            local type_key = p.type == 'id' and 'fp-bp-params.type-id' or 'fp-bp-params.type-number'
            add_editor_label(tbl, { '', '#' .. i .. ' ', { type_key } })
            add_editor_field(tbl, i, 'name', p.name, 180)
            if p.type == 'number' then
                add_editor_field(tbl, i, 'number', p.number, 70)
                add_editor_field(tbl, i, 'variable', p.variable, 60)
                add_editor_field(tbl, i, 'formula', p.formula, 180)
            else
                add_editor_label(tbl, '')
                add_editor_label(tbl, '')
                add_editor_label(tbl, '')
            end
        end
    end
    local buttons = editor.add({ type = 'flow', direction = 'horizontal' })
    buttons.style.top_margin = 4
    Gui.add(buttons, {
        type = 'button',
        caption = { 'fp-bp-params.editor-apply' },
        style = 'confirm_button',
        tags = { action = EDITOR_APPLY_ACTION },
    })
    Gui.add(buttons, {
        type = 'button',
        caption = raw and { 'fp-bp-params.editor-table' } or { 'fp-bp-params.editor-raw' },
        tooltip = raw and { 'fp-bp-params.editor-table-tooltip' } or { 'fp-bp-params.editor-raw-tooltip' },
        tags = { action = EDITOR_RAW_TOGGLE_ACTION },
    })
    local spacer = buttons.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    Gui.add(buttons, {
        type = 'button',
        caption = { 'fp-bp-params.editor-cancel' },
        style = 'back_button',
        tags = { action = EDITOR_CANCEL_ACTION },
    })
    set_status(player, nil)
    win.force_auto_center()
end
function BpParamsWindow.destroy(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
    BpParams.clear_slots(player.index)
end
local function add_slot_row(parent, which)
    local row = parent.add({ type = 'flow', direction = 'horizontal' })
    row.style.vertical_align = 'center'
    row.style.top_margin = 4
    Gui.add(row, {
        type = 'sprite-button',
        name = SLOT_BUTTON_NAMES[which],
        style = 'slot_button',
        tooltip = { 'fp-bp-params.slot-tooltip' },
        tags = { action = SLOT_ACTIONS[which] },
    })
    local texts = row.add({ type = 'flow', direction = 'vertical' })
    texts.style.left_margin = 8
    local header = texts.add({
        type = 'label',
        caption = { SLOT_LABEL_KEYS[which] },
    })
    header.style.font = 'default-bold'
    local state = texts.add({
        type = 'label',
        name = SLOT_STATE_NAMES[which],
        caption = { 'fp-bp-params.slot-empty' },
    })
    state.style.single_line = false
    state.style.maximal_width = 340
    local spacer = row.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    local edit = Gui.add(row, {
        type = 'sprite-button',
        name = EDIT_BUTTON_NAMES[which],
        sprite = 'utility/rename_icon',
        style = 'tool_button',
        tooltip = { 'fp-bp-params.edit-tooltip' },
        tags = { action = EDIT_ACTIONS[which] },
    })
    edit.enabled = false
end
function BpParamsWindow.open(player)
    if not player or not player.valid or not player.admin then return end
    if not BpParams.is_enabled() then return end
    local existing = get_window(player)
    if existing then
        player.opened = existing
        return
    end
    local frame = player.gui.screen.add({
        type = 'frame',
        name = WINDOW_NAME,
        direction = 'vertical',
    })
    frame.auto_center = true
    local titlebar = frame.add({ type = 'flow', direction = 'horizontal' })
    titlebar.add({
        type = 'label',
        caption = { 'fp-bp-params.window-title' },
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
        tooltip = { 'fp-bp-params.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        name = INSIDE_NAME,
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    inside.style.padding = 12
    inside.style.minimal_width = 480
    local instructions = inside.add({
        type = 'label',
        caption = { 'fp-bp-params.instructions' },
    })
    instructions.style.single_line = false
    instructions.style.maximal_width = 460
    instructions.style.bottom_margin = 6
    add_slot_row(inside, 'source')
    add_slot_row(inside, 'target')
    local status = inside.add({
        type = 'label',
        name = STATUS_LABEL_NAME,
        caption = '',
    })
    status.style.font_color = COLOR_ERROR
    status.style.top_margin = 6
    status.style.single_line = false
    status.style.maximal_width = 460
    status.visible = false
    local buttons = inside.add({ type = 'flow', direction = 'horizontal' })
    buttons.style.top_margin = 8
    Gui.add(buttons, {
        type = 'button',
        caption = { 'fp-bp-params.copy' },
        style = 'confirm_button',
        tags = { action = COPY_ACTION },
    })
    refresh_slot(player, 'source')
    refresh_slot(player, 'target')
    frame.force_auto_center()
    player.opened = frame
end
function BpParamsWindow.toggle(player)
    if not player or not player.valid then return end
    if get_window(player) then
        BpParamsWindow.destroy(player)
    else
        BpParamsWindow.open(player)
    end
end
Gui.on_click(CLOSE_ACTION, function(_, player)
    BpParamsWindow.destroy(player)
end)
local function on_slot_click(which)
    return function(_, player)
        if not player or not player.valid or not player.admin then return end
        local slots = BpParams.get_slots(player.index)
        local snapshot, err_key = BpParams.snapshot_cursor(player)
        if snapshot then
            slots[which] = snapshot
            set_status(player, nil)
        elseif err_key == 'fp-bp-params.empty-cursor' and slots[which] then
            slots[which] = nil
            set_status(player, nil)
        else
            set_status(player, err_key)
            return
        end
        if slots.editing == which then
            destroy_editor(player)
        end
        refresh_slot(player, which)
    end
end
Gui.on_click(SLOT_ACTIONS.source, on_slot_click('source'))
Gui.on_click(SLOT_ACTIONS.target, on_slot_click('target'))
Gui.on_click(COPY_ACTION, function(_, player)
    if not player or not player.valid or not player.admin then return end
    local slots = BpParams.get_slots(player.index)
    if not slots.source then
        set_status(player, 'fp-bp-params.missing-source')
        return
    end
    if not slots.target then
        set_status(player, 'fp-bp-params.missing-target')
        return
    end
    local result, err_key, count = BpParams.copy_parameters(slots.source.string, slots.target.string)
    if not result then
        set_status(player, err_key)
        return
    end
    if not give_result_to_cursor(player, result) then return end
    set_status(player, 'fp-bp-params.copy-success', COLOR_SUCCESS, count)
end)
local function on_edit_click(which)
    return function(_, player)
        if not player or not player.valid or not player.admin then return end
        if BpParams.get_slots(player.index).editing == which then
            destroy_editor(player)
        else
            open_editor(player, which)
        end
    end
end
Gui.on_click(EDIT_ACTIONS.source, on_edit_click('source'))
Gui.on_click(EDIT_ACTIONS.target, on_edit_click('target'))
Gui.on_click(EDITOR_RAW_TOGGLE_ACTION, function(_, player)
    if not player or not player.valid or not player.admin then return end
    local slots = BpParams.get_slots(player.index)
    local which = slots.editing
    if not which then return end
    open_editor(player, which, not slots.editing_raw)
end)
Gui.on_click(EDITOR_CANCEL_ACTION, function(_, player)
    if not player or not player.valid then return end
    destroy_editor(player)
end)
Gui.on_click(EDITOR_APPLY_ACTION, function(_, player)
    if not player or not player.valid or not player.admin then return end
    local slots = BpParams.get_slots(player.index)
    local which = slots.editing
    local snapshot = which and slots[which]
    if not snapshot then
        destroy_editor(player)
        return
    end
    local win = get_window(player)
    if not win then return end
    local params
    local raw_box = find_descendant(win, EDITOR_RAW_NAME)
    if raw_box then
        local parsed = helpers.json_to_table(raw_box.text)
        if type(parsed) ~= 'table' or (next(parsed) ~= nil and #parsed == 0) then
            set_status(player, 'fp-bp-params.invalid-json')
            return
        end
        for _, entry in ipairs(parsed) do
            if type(entry) ~= 'table' then
                set_status(player, 'fp-bp-params.invalid-json')
                return
            end
        end
        params = parsed
    else
        local scroll = find_descendant(win, EDITOR_SCROLL_NAME)
        local tbl = scroll and scroll.children[1]
        if not tbl or not tbl.valid then return end
        local err
        params, err = BpParams.get_parameters(snapshot.string)
        if not params then
            set_status(player, err)
            return
        end
        local edits = {}
        for _, cell in pairs(tbl.children) do
            if cell.valid and cell.type == 'textfield' then
                local tags = cell.tags
                local i = tags and tags.bp_edit_index
                if i then
                    edits[i] = edits[i] or {}
                    edits[i][tags.bp_edit_field] = cell.text
                end
            end
        end
        for i, fields in pairs(edits) do
            local p = params[i]
            if p then
                if fields.name ~= nil then
                    local name = trim(fields.name)
                    p.name = name ~= '' and name or nil
                end
                if p.type == 'number' then
                    if fields.number ~= nil then
                        local value = trim(fields.number)
                        if not tonumber(value) then
                            set_status(player, 'fp-bp-params.invalid-number', nil, i)
                            return
                        end
                        p.number = value
                    end
                    if fields.variable ~= nil then
                        local variable = trim(fields.variable)
                        p.variable = variable ~= '' and variable or nil
                    end
                    if fields.formula ~= nil then
                        local formula = trim(fields.formula)
                        if formula ~= '' then
                            p.formula = formula
                            p.dependent = true
                        else
                            p.formula = nil
                            p.dependent = nil
                        end
                    end
                end
            end
        end
    end
    local result, apply_err = BpParams.apply_parameters(snapshot.string, params)
    if not result then
        set_status(player, apply_err)
        return
    end
    if not give_result_to_cursor(player, result) then return end
    snapshot.string = result
    snapshot.param_count = #params
    refresh_slot(player, which)
    set_status(player, 'fp-bp-params.edit-success', COLOR_SUCCESS)
end)
Event.add(defines.events.on_gui_closed, function(event)
    if event.element and event.element.valid and event.element.name == WINDOW_NAME then
        local player = event.player_index and game.get_player(event.player_index)
        if player then
            BpParamsWindow.destroy(player)
        else
            event.element.destroy()
        end
    end
end)
Event.on_configuration_changed(function()
    for _, player in pairs(game.players) do
        BpParamsWindow.destroy(player)
    end
end)
return BpParamsWindow
