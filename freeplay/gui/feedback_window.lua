local Event = require 'lib.event'
local Gui = require 'gui.init'
local Feedback = require 'lib.feedback'
local WINDOW_NAME = 'feedback_window'
local CLOSE_ACTION = 'feedback_window_close'
local SUBMIT_ACTION = 'feedback_window_submit'
local CANCEL_ACTION = 'feedback_window_cancel'
local TEXTBOX_NAME = 'feedback_window_textbox'
local ERROR_LABEL_NAME = 'feedback_window_error'
local FeedbackWindow = {}
function FeedbackWindow.destroy(player)
    if not player or not player.valid then return end
    Gui.destroy_if_exists(player.gui.screen, WINDOW_NAME)
end
local function set_error(frame, locale_key)
    local error_label = frame[ERROR_LABEL_NAME]
    if not error_label or not error_label.valid then return end
    if locale_key then
        error_label.caption = { locale_key }
        error_label.visible = true
    else
        error_label.caption = ''
        error_label.visible = false
    end
end
function FeedbackWindow.open(player)
    if not player or not player.valid then return end
    if not Feedback.is_enabled() then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
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
        caption = { 'fp-feedback.window-title' },
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
        tooltip = { 'fp-feedback.close' },
        tags = { action = CLOSE_ACTION },
    })
    local inside = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame',
        direction = 'vertical',
    })
    inside.style.padding = 12
    inside.style.minimal_width = 480
    inside.add({
        type = 'label',
        caption = { 'fp-feedback.instructions',
                    tostring(Feedback.MAX_LENGTH) },
        style = 'label',
    }).style.bottom_margin = 6
    local textbox = inside.add({
        type = 'text-box',
        name = TEXTBOX_NAME,
        text = '',
    })
    textbox.word_wrap = true
    textbox.style.horizontally_stretchable = true
    textbox.style.maximal_width = 0
    textbox.style.minimal_height = 140
    textbox.style.maximal_height = 220
    local err_label = inside.add({
        type = 'label',
        name = ERROR_LABEL_NAME,
        caption = '',
    })
    err_label.style.font_color = { r = 1, g = 0.3, b = 0.3 }
    err_label.style.top_margin = 4
    err_label.visible = false
    local buttons = inside.add({ type = 'flow', direction = 'horizontal' })
    buttons.style.top_margin = 8
    Gui.add(buttons, {
        type = 'button',
        caption = { 'fp-feedback.submit' },
        style = 'confirm_button',
        tags = { action = SUBMIT_ACTION },
    })
    local spacer = buttons.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    Gui.add(buttons, {
        type = 'button',
        caption = { 'fp-feedback.cancel' },
        style = 'back_button',
        tags = { action = CANCEL_ACTION },
    })
    frame.force_auto_center()
    player.opened = frame
    textbox.focus()
end
function FeedbackWindow.toggle(player)
    if not player or not player.valid then return end
    local existing = player.gui.screen[WINDOW_NAME]
    if existing and existing.valid then
        FeedbackWindow.destroy(player)
    else
        FeedbackWindow.open(player)
    end
end
local function lookup_textbox(player)
    local win = player and player.valid and player.gui.screen[WINDOW_NAME]
    if not win or not win.valid then return nil end
    for _, child in pairs(win.children) do
        local found = child[TEXTBOX_NAME]
        if found and found.valid then return found, child end
    end
    return nil
end
local function close_via_event(event, player)
    FeedbackWindow.destroy(player)
end
Gui.on_click(CLOSE_ACTION, close_via_event)
Gui.on_click(CANCEL_ACTION, close_via_event)
Gui.on_click(SUBMIT_ACTION, function(_, player)
    if not player or not player.valid then return end
    local textbox, inside = lookup_textbox(player)
    if not textbox then return end
    local ok, err_key = Feedback.submit(player, textbox.text)
    if ok then
        FeedbackWindow.destroy(player)
        return
    end
    if err_key and inside then
        set_error(inside, err_key)
    end
end)
Event.add(defines.events.on_gui_closed, function(event)
    if event.element and event.element.valid and event.element.name == WINDOW_NAME then
        event.element.destroy()
    end
end)
return FeedbackWindow
