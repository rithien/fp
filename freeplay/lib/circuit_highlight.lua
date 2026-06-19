local Event = require 'lib.event'
local Config = require 'lib.config'
local Queue = require 'lib.circuit_highlight.queue'
local de = defines.events
local TOGGLE_ID = 'circuit_highlight'
local RED = { 1, 0, 0 }
local GREEN = { 0, 1, 0 }
local OPACITY = 1.0          
local OFFSET_VALUE = 0.125   
local NODE_RADIUS = 0.125    
local LINE_WIDTH = 2         
local ENTITIES_PER_TICK = 200 
local MAX_ENTITIES = 1000    
local INPUT_OUTPUT_COMBINATORS = {
    ['arithmetic-combinator'] = true,
    ['decider-combinator'] = true,
    ['selector-combinator'] = true,
}
local INPUT_CONNECTOR_IDS = {
    [defines.wire_connector_id.combinator_input_red] = true,
    [defines.wire_connector_id.combinator_input_green] = true,
}
local Public = {}
local function ensure_storage()
    if not storage.circuit_highlight then
        storage.circuit_highlight = { players = {}, user_disabled = {} }
    else
        if not storage.circuit_highlight.players then storage.circuit_highlight.players = {} end
        if not storage.circuit_highlight.user_disabled then storage.circuit_highlight.user_disabled = {} end
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function pdata(index)
    ensure_storage()
    local players = storage.circuit_highlight.players
    local pd = players[index]
    if not pd then
        pd = { rendered = {}, queue = Queue.new(), networks = {} }
        players[index] = pd
    end
    return pd
end
local function clear_player(index)
    ensure_storage()
    local pd = storage.circuit_highlight.players[index]
    if not pd then return end
    for _, obj in pairs(pd.rendered) do
        if obj.valid then obj.destroy() end
    end
    pd.rendered = {}
    pd.networks = {}
    if pd.queue then Queue.clear(pd.queue) end
end
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    ensure_storage()
    return not storage.circuit_highlight.user_disabled[index]
end
function Public.toggle_user(index)
    ensure_storage()
    local disabled = storage.circuit_highlight.user_disabled
    if disabled[index] then
        disabled[index] = nil
    else
        disabled[index] = true
        clear_player(index)
    end
    return not disabled[index]
end
function Public.is_active_for(index)
    return Config.is_enabled(TOGGLE_ID) and Public.is_user_enabled(index)
end
function Public.clear_all()
    ensure_storage()
    for index in pairs(storage.circuit_highlight.players) do
        clear_player(index)
    end
end
local function is_entity_valid(entity)
    return entity and entity.valid and entity.unit_number and entity.type ~= 'entity-ghost'
end
local function get_connected_networks(entity)
    if not is_entity_valid(entity) then return {} end
    local network_ids = {}
    for connector_type in pairs(entity.get_wire_connectors()) do
        local network = entity.get_circuit_network(connector_type)
        if network then
            network_ids[network.network_id] = network.wire_type
        end
    end
    return network_ids
end
local function get_directly_connected_entities(entity, network_id)
    local entities = { length = 0 }
    local networks = { length = 0 }
    for connector_type, connector in pairs(entity.get_wire_connectors()) do
        local network = entity.get_circuit_network(connector_type)
        if network then
            if not network_id or network.network_id == network_id then
                for _, connection in ipairs(connector.connections) do
                    entities[entities.length] = connection.target.owner
                    entities.length = entities.length + 1
                end
                networks[networks.length] = network.network_id
                networks.length = networks.length + 1
            end
        end
    end
    return entities, networks
end
local function get_connected_entities(entity, network_id)
    if not is_entity_valid(entity) then return {}, {} end
    local frontier = { entity }
    local added_ids = { [entity.unit_number] = true }
    local added_entities = { [entity] = true }
    local networks = {}
    if network_id then
        networks[network_id] = true
    else
        for nid in pairs(get_connected_networks(entity)) do
            networks[nid] = true
        end
    end
    local i = 1
    local last = 1
    while i <= MAX_ENTITIES and frontier[i] do
        local directly, new_networks = get_directly_connected_entities(frontier[i], network_id)
        for j = 0, directly.length - 1 do
            local other = directly[j]
            if other and other.unit_number and not added_ids[other.unit_number] then
                last = last + 1
                frontier[last] = other
                added_ids[other.unit_number] = true
                added_entities[other] = true
            end
        end
        for j = 0, new_networks.length - 1 do
            networks[new_networks[j]] = true
        end
        frontier[i] = nil
        i = i + 1
    end
    return added_entities, networks
end
local function get_color_and_offset(wire_type)
    local color, offset
    if wire_type == defines.wire_type.red then
        color = { r = RED[1], g = RED[2], b = RED[3] }
        offset = { x = OFFSET_VALUE, y = -OFFSET_VALUE }
    elseif wire_type == defines.wire_type.green then
        color = { r = GREEN[1], g = GREEN[2], b = GREEN[3] }
        offset = { x = -OFFSET_VALUE, y = OFFSET_VALUE }
    else
        color = { r = 0, g = 0, b = 0 }
        offset = { x = 0, y = 0 }
    end
    color.a = OPACITY
    color.r = math.min(color.r * color.a, 1)
    color.g = math.min(color.g * color.a, 1)
    color.b = math.min(color.b * color.a, 1)
    return color, offset
end
local function get_extra_offset(entity, connector_id)
    if not INPUT_OUTPUT_COMBINATORS[entity.type] then
        return { x = 0, y = 0 }
    end
    local offsets = {
        [defines.direction.north] = { x = 0, y = -0.5 },
        [defines.direction.south] = { x = 0, y = 0.5 },
        [defines.direction.west] = { x = -0.5, y = 0 },
        [defines.direction.east] = { x = 0.5, y = 0 },
    }
    local offset = offsets[entity.direction]
    if not offset then return { x = 0, y = 0 } end 
    if INPUT_CONNECTOR_IDS[connector_id] then
        offset.x = -offset.x
        offset.y = -offset.y
    end
    return offset
end
local function draw_connection(player, from, to, wire_type, network_id, from_conn, to_conn, rendered, net_offsets)
    local color, color_offset = get_color_and_offset(wire_type)
    local extra_from = get_extra_offset(from, from_conn)
    if to.unit_number and to.unit_number <= from.unit_number and from.surface == to.surface then
        local extra_to = get_extra_offset(to, to_conn)
        local line = rendering.draw_line({
            color = color,
            width = LINE_WIDTH,
            from = { entity = from, offset = { x = color_offset.x + extra_from.x, y = color_offset.y + extra_from.y } },
            to = { entity = to, offset = { x = color_offset.x + extra_to.x, y = color_offset.y + extra_to.y } },
            surface = from.surface,
            players = { player },
        })
        rendered[#rendered + 1] = line
    end
    net_offsets[network_id] = {
        color = color,
        offset = { x = color_offset.x + extra_from.x, y = color_offset.y + extra_from.y },
    }
    if to.unit_number == from.unit_number then
        net_offsets[network_id].output_offset = { x = color_offset.x - extra_from.x, y = color_offset.y - extra_from.y }
    end
end
local function render_nodes(player, entity, net_offsets, rendered)
    for _, data in pairs(net_offsets) do
        rendered[#rendered + 1] = rendering.draw_circle({
            color = data.color,
            filled = true,
            radius = NODE_RADIUS,
            target = { entity = entity, offset = data.offset },
            surface = entity.surface,
            players = { player },
        })
        if data.output_offset then
            rendered[#rendered + 1] = rendering.draw_circle({
                color = data.color,
                filled = true,
                radius = NODE_RADIUS,
                target = { entity = entity, offset = data.output_offset },
                surface = entity.surface,
                players = { player },
            })
        end
    end
end
local function visualize_entity(player, entity, in_network)
    if not player or not is_entity_valid(entity) then return end
    local pd = pdata(player.index)
    local rendered = pd.rendered
    local net_offsets = {}
    for connector_type, connector in pairs(entity.get_wire_connectors()) do
        local network = entity.get_circuit_network(connector_type)
        if network then
            local network_id = network.network_id
            if in_network == nil or in_network(network_id) then
                for _, connection in ipairs(connector.connections) do
                    local other_connector = connection.target
                    draw_connection(player, entity, other_connector.owner, connector.wire_type, network_id,
                        connector_type, other_connector.wire_connector_id, rendered, net_offsets)
                end
            end
        end
    end
    render_nodes(player, entity, net_offsets, rendered)
end
local function on_selected(event)
    local index = event.player_index
    clear_player(index)
    if not Public.is_active_for(index) then return end
    local player = game.get_player(index)
    if not player then return end
    local selected = player.selected
    if not is_entity_valid(selected) then return end
    local connected_networks = get_connected_networks(selected)
    local pd = pdata(index)
    local any = false
    for network_id in pairs(connected_networks) do
        pd.networks[network_id] = true
        any = true
        local entities = get_connected_entities(selected, network_id)
        for entity in pairs(entities) do
            Queue.push(pd.queue, entity, entity.unit_number)
        end
    end
    if not any then
        pd.networks = {}
    end
end
local function drain()
    local ch = storage.circuit_highlight
    if not ch or not ch.players then return end
    for index, pd in pairs(ch.players) do
        local q = pd.queue
        if q and q.first <= q.last then
            local player = game.get_player(index)
            if player and player.valid then
                local networks = pd.networks
                local in_network = function(network_id) return networks[network_id] end
                for _ = 1, ENTITIES_PER_TICK do
                    local entity = Queue.pop(q)
                    if not entity then break end
                    if is_entity_valid(entity) then
                        visualize_entity(player, entity, in_network)
                    end
                end
            else
                Queue.clear(q) 
            end
        end
    end
end
Event.add(de.on_selected_entity_changed, on_selected)
Event.on_nth_tick(1, drain)
Event.add(de.on_player_left_game, function(event)
    clear_player(event.player_index)
    if storage.circuit_highlight and storage.circuit_highlight.players then
        storage.circuit_highlight.players[event.player_index] = nil
    end
end)
return Public
