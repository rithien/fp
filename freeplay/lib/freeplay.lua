local Event = require 'lib.event'
local crash_site = require 'crash-site' 
local util = require 'util'             
local Freeplay = {}
local function data()
    if not storage.freeplay then
        storage.freeplay = {
            created_items = {},
            respawn_items = {},
            ship_items = {},
            debris_items = {},
            ship_parts = nil,
            disable_crashsite = false,
            skip_intro = false,
            custom_intro_message = nil,
            chart_distance = nil,
            touched = false,
            init = #game.players > 0,
        }
    end
    return storage.freeplay
end
local function setter(key)
    return function(value)
        local d = data()
        d[key] = value
        d.touched = true
    end
end
remote.add_interface('freeplay', {
    get_created_items = function() return data().created_items end,
    set_created_items = setter('created_items'),
    get_respawn_items = function() return data().respawn_items end,
    set_respawn_items = setter('respawn_items'),
    get_ship_items = function() return data().ship_items end,
    set_ship_items = setter('ship_items'),
    get_debris_items = function() return data().debris_items end,
    set_debris_items = setter('debris_items'),
    get_ship_parts = function() return data().ship_parts or crash_site.default_ship_parts() end,
    set_ship_parts = setter('ship_parts'),
    get_disable_crashsite = function() return data().disable_crashsite end,
    set_disable_crashsite = setter('disable_crashsite'),
    get_skip_intro = function() return data().skip_intro end,
    set_skip_intro = setter('skip_intro'),
    get_custom_intro_message = function() return data().custom_intro_message end,
    set_custom_intro_message = setter('custom_intro_message'),
    get_init_ran = function() return data().init end,
    set_chart_distance = function(value) data().chart_distance = tonumber(value) end,
})
local function create_crash_site_once(player)
    local d = data()
    if d.init then return end
    d.init = true
    if not d.touched or d.disable_crashsite then return end
    local surface = player.surface
    crash_site.create_crash_site(surface, { -5, -6 },
        util.copy(d.ship_items), util.copy(d.debris_items),
        util.copy(d.ship_parts or crash_site.default_ship_parts()))
    local r = d.chart_distance or 200
    local origin = player.force.get_spawn_position(surface)
    player.force.chart(surface, { { origin.x - r, origin.y - r }, { origin.x + r, origin.y + r } })
end
Event.add(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local d = data()
    if d.touched then
        util.insert_safe(player, d.created_items)
    end
    create_crash_site_once(player)
    if d.touched and d.custom_intro_message and not d.skip_intro then
        player.print(d.custom_intro_message)
    end
end)
Event.add(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local d = data()
    if d.touched then
        util.insert_safe(player, d.respawn_items)
    end
end)
return Freeplay
