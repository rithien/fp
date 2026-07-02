local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local TOGGLE_ID = 'always_day'
local function apply(state)
    for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and surface.planet then
            surface.always_day = state and true or false
        end
    end
end
Event.add(defines.events.on_surface_created, function(event)
    if not Config.is_enabled(TOGGLE_ID) then return end
    local surface = game.get_surface(event.surface_index)
    if surface and surface.valid and surface.planet then
        surface.always_day = true
    end
end)
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.always-day-caption' },
    tooltip = { 'fp-admin.always-day-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = apply,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.always-day-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
