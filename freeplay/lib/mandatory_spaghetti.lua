local Event = require 'lib.event'
local DebugLog = require 'lib.debug_log'
local config = require 'lib.mandatory_spaghetti.config'
local M = {}
if not config.enabled then return M end
local de = defines.events
local MSG_COLOR = { r = 0.6, g = 0.95, b = 0.8 } 
local REASON_MSG = {
    pattern = { 'fp-mandatory-spaghetti.died-pattern' },
    adjacency = { 'fp-mandatory-spaghetti.died-adjacency' },
    orphan = { 'fp-mandatory-spaghetti.died-orphan' },
}
local adjacent_blacklist = {
    ['curved-rail-a'] = true,
    ['elevated-curved-rail-a'] = true,
    ['curved-rail-b'] = true,
    ['elevated-curved-rail-b'] = true,
    ['half-diagonal-rail'] = true,
    ['elevated-half-diagonal-rail'] = true,
    ['legacy-curved-rail'] = true,
    ['legacy-straight-rail'] = true,
    ['cargo-landing-pad'] = true,
}
local pattern_blacklist = {
    ['electric-pole'] = true,
    ['gate'] = true,
    ['heat-interface'] = true,
    ['heat-pipe'] = true,
    ['inserter'] = true,
    ['lamp'] = true,
    ['pipe'] = true,
    ['infinity-pipe'] = true,
    ['pipe-to-ground'] = true,
    ['curved-rail-a'] = true,
    ['elevated-curved-rail-a'] = true,
    ['curved-rail-b'] = true,
    ['elevated-curved-rail-b'] = true,
    ['half-diagonal-rail'] = true,
    ['elevated-half-diagonal-rail'] = true,
    ['legacy-curved-rail'] = true,
    ['legacy-straight-rail'] = true,
    ['rail-ramp'] = true,
    ['straight-rail'] = true,
    ['elevated-straight-rail'] = true,
    ['rail-chain-signal'] = true,
    ['rail-signal'] = true,
    ['rail-support'] = true,
    ['lane-splitter'] = true,
    ['linked-belt'] = true,
    ['loader-1x1'] = true,
    ['loader'] = true,
    ['splitter'] = true,
    ['transport-belt'] = true,
    ['underground-belt'] = true,
    ['valve'] = true,
    ['car'] = true,
    ['artillery-wagon'] = true,
    ['cargo-wagon'] = true,
    ['infinity-cargo-wagon'] = true,
    ['fluid-wagon'] = true,
    ['locomotive'] = true,
    ['spider-vehicle'] = true,
    ['wall'] = true,
}
local function die(source, event, reason)
    local surface = source.surface
    local pos = source.position
    local force = source.force
    local entity_name = source.name
    if event.player_index then
        local player = game.get_player(event.player_index)
        if player then
            player.print(REASON_MSG[reason], { color = MSG_COLOR })
        end
    end
    DebugLog.log('[spaghetti] %s died (%s) at [%d,%d] surface=%d builder=%s',
        entity_name, reason, math.floor(pos.x), math.floor(pos.y), surface.index,
        event.player_index and game.get_player(event.player_index).name or 'robot')
    if config.casual_mode then
        local products = source.prototype.mineable_properties.products or {}
        local temp = game.create_inventory(#products)
        source.mine({ force = true, inventory = temp })
        for i = 1, #temp do
            local stack = temp[i]
            if stack.valid_for_read then
                surface.spill_item_stack({
                    position = pos,
                    stack = stack,
                    enable_looted = true,
                    force = force,
                    allow_belts = false,
                })
            end
        end
        temp.destroy()
    else
        source.die(force)
    end
    local ghost = surface.find_entity('entity-ghost', pos)
    if ghost then ghost.destroy() end
end
local function adjacency(source, event)
    if adjacent_blacklist[source.type] then return end
    if event.player_index then
        local player = game.get_player(event.player_index)
        local cursor = player.cursor_stack
        if cursor and cursor.valid_for_read then
            if cursor.type == 'rail-planner' then return end
        end
    end
    local surface = source.surface
    local bb = source.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local entities = surface.find_entities_filtered({
        area = { { lt.x - 1, lt.y - 1 }, { rb.x + 1, rb.y + 1 } },
        force = source.force,
    })
    for _, entity in pairs(entities) do
        if entity == source then goto continue end
        if entity.prototype.is_building then
            goto forelse
        end
        ::continue::
    end
    die(source, event, 'adjacency')
    ::forelse::
end
local function find_pattern(source, offset)
    local pos = source.position
    if pos.x > offset.x then
        pos.x, offset.x = offset.x, pos.x
    end
    if pos.y > offset.y then
        pos.y, offset.y = offset.y, pos.y
    end
    local bb = source.prototype.collision_box
    local is_rectangular = bb.left_top.x ~= bb.left_top.y or bb.right_bottom.x ~= bb.right_bottom.y or bb.left_top.x ~= -bb.right_bottom.x
    local entities = source.surface.find_entities_filtered({
        area = { pos, offset },
        name = source.name,
        direction = is_rectangular and source.direction or nil,
        force = source.force,
    })
    pos = source.position
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity == source then
            table.remove(entities, i)
        end
        local pos2 = entity.position
        if not (pos2.x == pos.x or pos2.y == pos.y) then
            table.remove(entities, i)
        end
    end
    return entities
end
local function draw_line(surface, from, to)
    return rendering.draw_line({
        width = 4,
        color = { 1, 1, 1 },
        from = from,
        to = to,
        surface = surface,
        dash_length = 0.5,
        gap_length = 0.5,
        time_to_live = 60,
        dash_offset = 0.25,
        blink_interval = 15,
    })
end
local function pattern(source, event)
    if pattern_blacklist[source.type] then return end
    local bb = source.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local pos = source.position
    local surface = source.surface
    local offsets = {
        { x = 0, y = lt.y - 4 - pos.y },
        { x = rb.x + 4 - pos.x, y = 0 },
        { x = 0, y = rb.y + 4 - pos.y },
        { x = lt.x - 4 - pos.x, y = 0 },
    }
    for _, offset in pairs(offsets) do
        local entities = find_pattern(source, { x = pos.x + offset.x, y = pos.y + offset.y })
        for _, entity in pairs(entities) do
            local pos2 = entity.position
            local third = find_pattern(entity, { x = pos2.x + offset.x, y = pos2.y + offset.y })[1]
            if third then
                draw_line(surface, source.position, third)
                die(source, event, 'pattern')
                return
            else
                third = find_pattern(source, { x = pos.x - offset.x, y = pos.y - offset.y })[1]
                if third then
                    draw_line(surface, entity, third)
                    die(source, event, 'pattern')
                    return
                end
            end
        end
    end
end
local function has_adjacent_building(entity, excluded)
    local bb = entity.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local entities = entity.surface.find_entities_filtered({
        area = { { lt.x - 1, lt.y - 1 }, { rb.x + 1, rb.y + 1 } },
        force = entity.force,
    })
    for _, e in pairs(entities) do
        if e ~= entity and e ~= excluded and e.valid and e.prototype.is_building then
            return true
        end
    end
    return false
end
local function on_building_removed(event)
    local removed = event.entity
    if not removed or not removed.valid then return end
    local force_name = removed.force.name
    if force_name == 'enemy' or force_name == 'neutral' then return end
    if not removed.prototype.is_building then return end
    local bb = removed.bounding_box
    local lt, rb = bb.left_top, bb.right_bottom
    local neighbors = removed.surface.find_entities_filtered({
        area = { { lt.x - 1, lt.y - 1 }, { rb.x + 1, rb.y + 1 } },
        force = removed.force,
    })
    for _, n in pairs(neighbors) do
        if n ~= removed and n.valid and n.prototype.is_building
            and not adjacent_blacklist[n.type]
            and not has_adjacent_building(n, removed) then
            die(n, event, 'orphan')
        end
    end
end
local function build_handler(event)
    local source = event.entity
    if not source or not source.valid then return end
    if not source.prototype.is_building then return end
    if config.adjacency_enabled then
        adjacency(source, event)
    end
    if not source.valid then return end
    pattern(source, event)
end
Event.add(de.on_built_entity, build_handler)
Event.add(de.on_robot_built_entity, build_handler)
if config.adjacency_enabled and config.orphan_enforcement then
    Event.add(de.on_player_mined_entity, on_building_removed)
    Event.add(de.on_robot_mined_entity, on_building_removed)
    Event.add(de.on_entity_died, on_building_removed)
end
return M
