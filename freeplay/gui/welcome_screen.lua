local Event = require 'lib.event'
local Server = require 'lib.server'
local Token = require 'lib.token'
local Gui = require 'gui.init'
local FRAME_NAME = 'fp_welcome_frame'
local DYNAMIC_NAME = 'fp_welcome_dynamic'
local CLOSE_ACTION = 'fp_welcome_close'
local Public = {}
local function bind_storage()
    storage.welcome = storage.welcome or { seen = {} }
    storage.welcome.seen = storage.welcome.seen or {}
end
Event.on_init(bind_storage)
Event.on_configuration_changed(bind_storage)
local function render_news(dynamic)
    if not (dynamic and dynamic.valid) then return end
    dynamic.clear()
    local header = dynamic.add({
        type = 'label',
        caption = { 'fp-welcome.news-header' }
    })
    header.style.font = 'default-bold'
    header.style.bottom_margin = 4
    local news = storage.welcome and storage.welcome.news
    local body
    if type(news) == 'string' and news ~= '' then
        body = dynamic.add({ type = 'label', caption = news })
    else
        body = dynamic.add({ type = 'label', caption = { 'fp-welcome.news-empty' } })
    end
    body.style.single_line = false
    body.style.maximal_width = 480
end
local function refresh_open_panels()
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.screen[FRAME_NAME]
        if frame and frame.valid then
            local dynamic = frame[DYNAMIC_NAME]
            if dynamic and dynamic.valid then
                render_news(dynamic)
            end
        end
    end
end
local refresh_news_token = Token.register(function(data)
    bind_storage()
    storage.welcome.news = data.value 
    refresh_open_panels()
end)
local function build_panel(player)
    Gui.destroy_if_exists(player.gui.screen, FRAME_NAME)
    local frame = player.gui.screen.add({
        type = 'frame',
        name = FRAME_NAME,
        direction = 'vertical'
    })
    frame.auto_center = true
    frame.style.width = 520
    local top = frame.add({
        type = 'frame',
        style = 'inside_shallow_frame_with_padding',
        direction = 'vertical'
    })
    top.style.minimal_height = 280
    top.style.horizontally_stretchable = true
    top.add({
        type = 'label',
        caption = { 'fp-welcome.title' },
        style = 'frame_title'
    })
    local welcome = top.add({
        type = 'label',
        caption = { 'fp-welcome.intro' }
    })
    welcome.style.single_line = false
    welcome.style.maximal_width = 480
    welcome.style.top_margin = 8
    welcome.style.bottom_margin = 8
    top.add({ type = 'line' })
    local warn_title = top.add({
        type = 'label',
        caption = { 'fp-welcome.warning-title' }
    })
    warn_title.style.top_margin = 8
    local warn = top.add({
        type = 'label',
        caption = { 'fp-welcome.warning-body' }
    })
    warn.style.single_line = false
    warn.style.maximal_width = 480
    warn.style.top_margin = 4
    local dynamic = frame.add({
        type = 'frame',
        name = DYNAMIC_NAME,
        style = 'inside_shallow_frame_with_padding',
        direction = 'vertical'
    })
    dynamic.style.minimal_height = 140
    dynamic.style.top_margin = 8
    dynamic.style.horizontally_stretchable = true
    render_news(dynamic)
    Server.try_get_data('server_meta', 'news', refresh_news_token)
    local footer = frame.add({ type = 'flow', direction = 'horizontal' })
    footer.style.top_margin = 8
    footer.style.horizontally_stretchable = true
    local spacer = footer.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true
    Gui.add(footer, {
        type = 'button',
        caption = { 'fp-welcome.understand' },
        style = 'confirm_button',
        tags = { action = CLOSE_ACTION }
    })
end
Gui.on_click(CLOSE_ACTION, function(_, player)
    if player and player.valid then
        Gui.destroy_if_exists(player.gui.screen, FRAME_NAME)
    end
end)
local function maybe_show(player)
    bind_storage()
    if storage.welcome.seen[player.name] then
        return
    end
    storage.welcome.seen[player.name] = true
    build_panel(player)
end
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    maybe_show(player)
end)
Server.on_data_set_changed('server_meta', function(data)
    if data.key ~= 'news' then return end
    bind_storage()
    storage.welcome.news = data.value
    refresh_open_panels()
end)
Public.bind_storage = bind_storage
function Public.show(player)
    if not (player and player.valid) then return end
    bind_storage()
    storage.welcome.seen[player.name] = true
    build_panel(player)
end
function Public.reset(player_name)
    bind_storage()
    storage.welcome.seen[player_name] = nil
end
function Public.reset_all()
    bind_storage()
    storage.welcome.seen = {}
end
return Public
