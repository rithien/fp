local Event = require 'lib.event'
local Gui = require 'gui.init'
local Session = require 'lib.sessions'
local TopButtons = require 'gui.top_buttons'
local de = defines.events
local BUTTON_NAME = 'status_top_button'
local NOOP_ACTION = 'status_top_button_noop'
local Public = {}
local function build_tooltip(player)
    if Session.is_manually_untrusted(player) then
        return { 'fp-status.untrusted-revoked-tooltip' }
    end
    local remaining = Session.get_remaining_trust_ticks(player)
    local total_minutes = math.ceil(remaining / 3600) 
    if total_minutes < 1 then total_minutes = 1 end
    local hours = math.floor(total_minutes / 60)
    local minutes = total_minutes % 60
    return { 'fp-status.untrusted-tooltip', hours, minutes }
end
local function ensure_button(player)
    if not (player and player.valid) then
        return
    end
    local existing = Gui.get_top_element(player, BUTTON_NAME)
    if Session.get_trusted_player(player) then
        if existing then existing.destroy() end
        return
    end
    if existing then
        existing.tooltip = build_tooltip(player)
        return
    end
    Gui.add(player.gui.top, {
        type = 'sprite-button',
        name = BUTTON_NAME,
        sprite = 'virtual-signal/signal-red',
        tooltip = build_tooltip(player),
        tags = { action = NOOP_ACTION }
    })
end
Event.add(de.on_player_joined_game, function(event)
    ensure_button(game.get_player(event.player_index))
end)
Event.add(Session.events.on_player_trusted, function(event)
    ensure_button(game.get_player(event.player_index))
end)
Event.add(Session.events.on_player_untrusted, function(event)
    ensure_button(game.get_player(event.player_index))
end)
Event.add(Session.events.on_trust_refreshed, function(event)
    ensure_button(game.get_player(event.player_index))
end)
TopButtons.register(ensure_button)
Event.on_configuration_changed(function()
    for _, p in pairs(game.connected_players) do
        Gui.destroy_if_exists(p.gui.top, BUTTON_NAME)
        ensure_button(p)
    end
end)
return Public
