local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local de = defines.events
local TOGGLE_ID = 'no_handcrafting'
local function apply_to_force(force, no_handcrafting)
    if not force or not force.valid then return end
    for _, recipe in pairs(force.recipes) do
        force.set_hand_crafting_disabled_for_recipe(recipe.name, no_handcrafting)
    end
end
local function apply(state)
    local force = game.forces.player
    if force and force.valid then
        apply_to_force(force, state and true or false)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.no-handcrafting-caption' },
    tooltip = { 'fp-admin.no-handcrafting-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = apply,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.no-handcrafting-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
Event.add(de.on_research_finished, function(event)
    if not Config.is_enabled(TOGGLE_ID) then return end
    local research = event.research
    if not research or not research.valid then return end
    local force = research.force
    if force and force.valid then
        apply_to_force(force, true)
    end
end)
