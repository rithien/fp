local Event = require 'lib.event'
local Config = require 'lib.config'
local de = defines.events
local TOGGLE_ID = 'auto_pipe_connectors'
local direction_vectors = {
    [defines.direction.north] = { 0, -1 },
    [defines.direction.east]  = { 1, 0 },
    [defines.direction.south] = { 0, 1 },
    [defines.direction.west]  = { -1, 0 },
}
local directions_to_neighbors = {
    [defines.direction.north] = {
        { pos = { -1, -1 }, dir = defines.direction.east },
        { pos = { 0, -2 }, dir = defines.direction.south },
        { pos = { 1, -1 }, dir = defines.direction.west },
    },
    [defines.direction.east] = {
        { pos = { 1, -1 }, dir = defines.direction.south },
        { pos = { 2, 0 }, dir = defines.direction.west },
        { pos = { 1, 1 }, dir = defines.direction.north },
    },
    [defines.direction.south] = {
        { pos = { 1, 1 }, dir = defines.direction.west },
        { pos = { 0, 2 }, dir = defines.direction.north },
        { pos = { -1, 1 }, dir = defines.direction.east },
    },
    [defines.direction.west] = {
        { pos = { -1, 1 }, dir = defines.direction.north },
        { pos = { -2, 0 }, dir = defines.direction.east },
        { pos = { -1, -1 }, dir = defines.direction.south },
    },
}
local Public = {}
local rebuild_index
local function ensure_storage()
    local s = storage.auto_pipe_connectors
    if not s then
        storage.auto_pipe_connectors = { pipe_lookup = {}, index_rebuilt_tick = -1, user_disabled = {}, index_built = false }
    else
        s.pipe_lookup = s.pipe_lookup or {}
        s.user_disabled = s.user_disabled or {}
        if s.index_rebuilt_tick == nil then s.index_rebuilt_tick = -1 end
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function is_user_enabled(index)
    ensure_storage()
    return not storage.auto_pipe_connectors.user_disabled[index]
end
local function is_active_for(index)
    return Config.is_enabled(TOGGLE_ID) and is_user_enabled(index)
end
local function entity_type_or_ghost_type(entity)
    return entity.type == 'entity-ghost' and entity.ghost_type or entity.type
end
local function should_place_based_on_neighbor_fluidbox_prototypes(entity, position)
    local fluidbox = entity.fluidbox
    for i = 1, #fluidbox do
        for _, pipe_connection in pairs(fluidbox.get_pipe_connections(i)) do
            if position[1] == math.floor((pipe_connection.target_position.x + 0.25) * 2) / 2 and
                position[2] == math.floor((pipe_connection.target_position.y + 0.25) * 2) / 2 then
                return true
            end
        end
    end
    return false
end
local function on_built_entity(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity_type_or_ghost_type(entity) ~= 'pipe-to-ground' then return end
    if not event.player_index then return end
    if not is_active_for(event.player_index) then return end
    if not storage.auto_pipe_connectors.index_built then rebuild_index() end
    local underground_entity_name
    local placing_ghost
    if entity.type == 'entity-ghost' then
        placing_ghost = true
        underground_entity_name = entity.ghost_name
    else
        placing_ghost = false
        underground_entity_name = entity.name
    end
    local lookup_entry = storage.auto_pipe_connectors.pipe_lookup[underground_entity_name]
    if not lookup_entry then return end 
    local underground_surface = entity.surface
    local underground_direction = entity.direction
    local underground_position = entity.position
    local neighbors_directions = directions_to_neighbors[underground_direction]
    local pipe_position_delta = direction_vectors[underground_direction]
    if not neighbors_directions or not pipe_position_delta then return end 
    local pipe_item_name = lookup_entry.item
    local pipe_entity_name = lookup_entry.entity
    local pipe_position = {
        underground_position.x + pipe_position_delta[1],
        underground_position.y + pipe_position_delta[2],
    }
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local inventory = player.get_main_inventory()
    local pipe_stack
    if not placing_ghost then
        if inventory then
            pipe_stack = inventory.find_item_stack(pipe_item_name)
            placing_ghost = not pipe_stack
        else
            placing_ghost = true
        end
    end
    local place_tile = false
    local existing_tile = underground_surface.get_tile(pipe_position[1], pipe_position[2])
    local cover_tile = existing_tile.prototype.default_cover_tile
    local tile_ghost_definition
    if cover_tile then
        if cover_tile.name == 'ice-platform' then
            return
        end
        placing_ghost = true
        local existing_tile_ghost = underground_surface.find_entity('tile-ghost', pipe_position)
        if existing_tile_ghost == nil then
            place_tile = true
            tile_ghost_definition = {
                name = 'tile-ghost',
                position = pipe_position,
                inner_name = cover_tile.name,
                force = entity.force,
                player = event.player_index,
                raise_built = true,
                create_build_effect_smoke = true,
                spawn_decorations = true,
                build_check_type = defines.build_check_type.script_ghost,
            }
            if not underground_surface.can_place_entity(tile_ghost_definition) then
                return
            end
        end
    end
    local pipe_entity_definition = {
        name = placing_ghost and 'entity-ghost' or pipe_entity_name,
        position = pipe_position,
        force = entity.force,
        player = event.player_index,
        raise_built = true,
        create_build_effect_smoke = true,
        spawn_decorations = true,
        build_check_type = placing_ghost and defines.build_check_type.script_ghost or defines.build_check_type.manual,
    }
    if placing_ghost then
        pipe_entity_definition.inner_name = pipe_entity_name
    end
    if not underground_surface.can_place_entity(pipe_entity_definition) then
        return
    end
    if placing_ghost then
        local found_entities = underground_surface.find_entities({ pipe_entity_definition.position, pipe_entity_definition.position })
        for _, found_entity in pairs(found_entities) do
            if found_entity.type ~= 'tile-ghost' then
                return
            end
        end
    end
    if underground_surface.can_fast_replace(pipe_entity_definition) then
        local ghost = underground_surface.find_entity('entity-ghost', pipe_entity_definition.position)
        if ghost and ghost.ghost_name == pipe_entity_name then
        else
            return
        end
    end
    for _, neighbor_candidate in pairs(neighbors_directions) do
        local candidate_pos = { underground_position.x + neighbor_candidate.pos[1], underground_position.y + neighbor_candidate.pos[2] }
        local place = false
        local neighbor_entity = underground_surface.find_entity(underground_entity_name, candidate_pos)
        if neighbor_entity and neighbor_entity.name == underground_entity_name and neighbor_entity.direction == neighbor_candidate.dir then
            place = true
        end
        if not place then
            local neighbor_ghost = underground_surface.find_entity('entity-ghost', candidate_pos)
            if neighbor_ghost and neighbor_ghost.ghost_name == underground_entity_name and neighbor_ghost.direction == neighbor_candidate.dir then
                place = true
                placing_ghost = true
            end
        end
        if not place then
            local neighbor_entities = underground_surface.find_entities({ candidate_pos, candidate_pos })
            for _, ne in pairs(neighbor_entities) do
                local entity_type = entity_type_or_ghost_type(ne)
                if entity_type == 'fluid-wagon' then
                    goto continue_neighbor_entities
                end
                if (entity_type ~= 'pipe' and entity_type ~= 'pipe-to-ground') and (ne.fluidbox and #ne.fluidbox > 0) then
                    if should_place_based_on_neighbor_fluidbox_prototypes(ne, pipe_position) then
                        place = true
                        goto bail_neighbor_entities
                    end
                end
                ::continue_neighbor_entities::
            end
        end
        ::bail_neighbor_entities::
        if place then
            if pipe_entity_definition.name ~= 'entity-ghost' then
                if inventory then
                    inventory.remove({ name = pipe_item_name })
                else
                    log('[auto_pipe_connectors] postawiono pipe za darmo (gracz ' .. player.name ..
                        ' nie miał main inventory) — nieoczekiwane, zgłoś buga.')
                end
            end
            local tile_failed = false
            if place_tile then
                tile_failed = not underground_surface.create_entity(tile_ghost_definition)
            end
            if not tile_failed then
                underground_surface.create_entity(pipe_entity_definition)
            end
            break
        end
    end
end
function rebuild_index()
    ensure_storage()
    local s = storage.auto_pipe_connectors
    if s.index_rebuilt_tick == game.tick then
        return
    end
    s.index_rebuilt_tick = game.tick
    local lookup = s.pipe_lookup
    local underground_recipe_prototypes = prototypes.get_recipe_filtered({
        { filter = 'has-product-item', elem_filters = { { filter = 'place-result', elem_filters = { { filter = 'type', type = 'pipe-to-ground' } } } } },
        { mode = 'and', filter = 'has-ingredient-item', elem_filters = { { filter = 'place-result', elem_filters = { { filter = 'type', type = 'pipe' } } } } },
    })
    for _, underground_recipe_prototype in pairs(underground_recipe_prototypes) do
        local underground_entity_name
        local pipe_item_name
        local pipe_entity_name
        for _, product in pairs(underground_recipe_prototype.products) do
            local result = product.type == 'item' and prototypes.item[product.name].place_result
            if result and prototypes.entity[result.name].type == 'pipe-to-ground' then
                underground_entity_name = result.name
                break
            end
        end
        if underground_entity_name == nil then goto continue_underground_recipe_prototype end
        for _, ingredient in pairs(underground_recipe_prototype.ingredients) do
            local result = ingredient.type == 'item' and prototypes.item[ingredient.name].place_result
            if result and prototypes.entity[result.name].type == 'pipe' then
                pipe_item_name = ingredient.name
                pipe_entity_name = result.name
                break
            end
        end
        if underground_entity_name and pipe_item_name and pipe_entity_name then
            lookup[underground_entity_name] = { item = pipe_item_name, entity = pipe_entity_name }
        end
        ::continue_underground_recipe_prototype::
    end
    s.index_built = true
    local n = 0
    for _ in pairs(lookup) do n = n + 1 end
    log('[auto_pipe_connectors] pipe_lookup zbudowany: ' .. n .. ' wpisów (mapowanie pipe-to-ground → pipe).')
end
Event.on_init(rebuild_index)
Event.on_configuration_changed(rebuild_index)
Event.add(de.on_built_entity, on_built_entity)
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    return is_user_enabled(index)
end
function Public.set_user_enabled(index, enabled)
    ensure_storage()
    storage.auto_pipe_connectors.user_disabled[index] = (not enabled) or nil
    return enabled and true or false
end
function Public.toggle_user(index)
    return Public.set_user_enabled(index, not is_user_enabled(index))
end
return Public
