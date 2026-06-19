local AdminPanel = require 'gui.admin_panel'
local Config = require 'lib.config'
local Event = require 'lib.event'
local de = defines.events
local TOGGLE_ID = 'fast_start_mech'
local ARMOR_NAME = 'mech-armor'
local ARMOR_INVENTORY = defines.inventory.character_armor
local EQUIPMENT = {
    'fission-reactor-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'exoskeleton-equipment',
    'energy-shield-mk2-equipment',
    'energy-shield-mk2-equipment',
    'personal-roboport-mk2-equipment',
    'personal-roboport-mk2-equipment',
    'night-vision-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment',
    'battery-mk3-equipment'
}
local ROBOTS_NAME = 'construction-robot'
local ROBOTS_COUNT = 50
local function ensure_storage()
    if not storage.fast_start_mech_given then
        storage.fast_start_mech_given = {}
    end
end
local function has_received(player)
    ensure_storage()
    return storage.fast_start_mech_given[player.name] == true
end
local function mark_received(player)
    ensure_storage()
    storage.fast_start_mech_given[player.name] = true
end
local function give_or_spill(player, name, count)
    local inserted = 0
    pcall(function() inserted = player.insert({ name = name, count = count }) or 0 end)
    local remainder = count - inserted
    if remainder > 0 then
        pcall(function()
            player.surface.spill_item_stack({
                position = player.position,
                stack = { name = name, count = remainder },
                enable_looted = true,
                force = player.force,
                allow_belts = false,
            })
        end)
        return false
    end
    return true
end
local function give_auto_equipped(player)
    local armor_inv = player.get_inventory(ARMOR_INVENTORY)
    local ok = pcall(function() armor_inv.insert({ name = ARMOR_NAME, count = 1 }) end)
    if not ok then return false end
    local armor_stack = armor_inv[1]
    if not armor_stack or not armor_stack.valid_for_read then return false end
    local grid = armor_stack.grid
    if grid then
        for _, eq_name in ipairs(EQUIPMENT) do
            pcall(function() grid.put({ name = eq_name }) end)
        end
    end
    give_or_spill(player, ROBOTS_NAME, ROBOTS_COUNT)
    return true
end
local function give_loose(player)
    local all_fit = give_or_spill(player, ARMOR_NAME, 1)
    local counts = {}
    for _, eq_name in ipairs(EQUIPMENT) do
        counts[eq_name] = (counts[eq_name] or 0) + 1
    end
    for name, count in pairs(counts) do
        if not give_or_spill(player, name, count) then all_fit = false end
    end
    if not give_or_spill(player, ROBOTS_NAME, ROBOTS_COUNT) then all_fit = false end
    if not all_fit then
        player.print(
            { 'fp-admin.fast-start-mech-spill' },
            { color = { r = 1, g = 0.7, b = 0 } }
        )
    end
    return true
end
local function give_to_player(player)
    if not player or not player.valid then return false end
    if has_received(player) then return false end
    local character = player.character
    if not character or not character.valid then return false end
    local armor_inv = player.get_inventory(ARMOR_INVENTORY)
    if not armor_inv or not armor_inv.valid then return false end
    local ok
    if armor_inv.is_empty() then
        ok = give_auto_equipped(player)
    else
        ok = give_loose(player)
    end
    if not ok then return false end
    mark_received(player)
    return true
end
local function give_to_all_online()
    local count = 0
    for _, player in pairs(game.connected_players) do
        if give_to_player(player) then
            count = count + 1
        end
    end
    return count
end
AdminPanel.register_toggle({
    id = TOGGLE_ID,
    caption = { 'fp-admin.fast-start-mech-caption' },
    tooltip = { 'fp-admin.fast-start-mech-tooltip' },
    get_state = function() return Config.is_enabled(TOGGLE_ID) end,
    apply = function(state)
        if state then
            Config.set('fast_start', false)
            give_to_all_online()
        end
    end,
    on_change = function(new_state, player)
        Config.set(TOGGLE_ID, new_state)
        if new_state then
            Config.set('fast_start', false)
            AdminPanel.refresh_open_panel(player)
        end
        local distributed = 0
        if new_state then
            distributed = give_to_all_online()
        end
        local state = { new_state and 'fp-admin.on' or 'fp-admin.off' }
        local msg
        if new_state and distributed > 0 then
            msg = { 'fp-admin.broadcast-toggle-count', { 'fp-admin.fast-start-mech-caption' }, state, player.name, distributed }
        else
            msg = { 'fp-admin.broadcast-toggle', { 'fp-admin.fast-start-mech-caption' }, state, player.name }
        end
        game.print(msg, { color = { r = 1, g = 1, b = 0 } })
    end,
})
Event.add(de.on_player_joined_game, function(event)
    if not Config.is_enabled(TOGGLE_ID) then return end
    local player = game.get_player(event.player_index)
    give_to_player(player)
end)
local Public = {}
function Public.force_give_to_online_unarmored()
    ensure_storage()
    local count = 0
    for _, player in pairs(game.connected_players) do
        if player.valid and player.character and player.character.valid then
            local armor_inv = player.get_inventory(ARMOR_INVENTORY)
            if armor_inv and armor_inv.valid and armor_inv.is_empty() then
                storage.fast_start_mech_given[player.name] = nil 
                if give_to_player(player) then
                    count = count + 1
                end
            end
        end
    end
    return count
end
return Public
