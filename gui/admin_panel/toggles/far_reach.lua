local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local de = defines.events
local TOGGLE_ID = 'far_reach'
local BONUSES = {
    character_build_distance_bonus = 150,
    character_reach_distance_bonus = 150,
    character_resource_reach_distance_bonus = 150,
    character_item_drop_distance_bonus = 150,
    character_item_pickup_distance_bonus = 0
}
local function apply_to_force(force, enabled)
    if not force or not force.valid then return end
    for key, value in pairs(BONUSES) do
        force[key] = enabled and value or 0
    end
end
local function clear_character_bonus(player)
    local character = player and player.valid and player.character
    if not character or not character.valid then return end
    for key in pairs(BONUSES) do
        character[key] = 0
    end
end
local function apply(state)
    for _, force in pairs(game.forces) do
        apply_to_force(force, state)
    end
    for _, player in pairs(game.connected_players) do
        clear_character_bonus(player)
    end
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.far-reach-caption' },
    tooltip = { 'fp-admin.far-reach-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = apply,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        apply(new_state)
        game.print({ 'fp-admin.broadcast-toggle', { 'fp-admin.far-reach-caption' },
                     { new_state and 'fp-admin.on' or 'fp-admin.off' }, player.name },
                   { color = { r = 1, g = 1, b = 0 } })
    end,
})
Event.add(de.on_force_created, function(event)
    if not Config.is_enabled(TOGGLE_ID) then return end
    apply_to_force(event.force, true)
end)
Event.add(de.on_player_joined_game, function(event)
    clear_character_bonus(game.get_player(event.player_index))
end)
