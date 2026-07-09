local const = require 'lib.belt_visualizer.constants'
local utils = require 'lib.belt_visualizer.utils'
local draw = require 'lib.belt_visualizer.rendering'
local get_belt_type = utils.get_belt_type
local empty_check = utils.empty_check
local check_entity = utils.check_entity
local lane_cycle = const.lane_cycle
local side_cycle = const.side_cycle
local straight = const.straight
local underground = const.underground
local dash = const.dash
local splitter = const.splitter
local lane_splitter = const.lane_splitter
local loader = const.loader
local loader_1x1 = const.loader_1x1
local linked_belt = const.linked_belt
local CONTAINER_PASSTHROUGH = true
local function is_clockwise(entity, output)
    return (output.direction - entity.direction) % 16 == 4
end
local function get_splitter_sides(entity, belt)
    local direction = entity.direction
    local position = entity.position
    local belt_position = belt.position
    local axis = direction % 8 == 0 and 'x' or 'y'
    if position[axis] == belt_position[axis] then return side_cycle.both end
    return (position[axis] > belt_position[axis]) ~= (direction >= 8) and side_cycle.left or side_cycle.right
end
local function get_filter_side(pd, entity)
    if not pd.filter then return end
    if entity.type == 'entity-ghost' then return end
    local splitter_filter = entity.splitter_filter
    if not splitter_filter then return end
    local output_priority = entity.splitter_output_priority
    if output_priority == 'none' then return end
    local name = splitter_filter.name
    if type(name) ~= 'string' then name = name.name end
    return (output_priority == 'left') == (pd.filter == name) and 'left' or 'right'
end
local function get_input_paths(check, lanes)
    for lane, paths in pairs(check) do
        if paths[1] then
            lanes[lane] = true
        end
    end
end
local function get_input_lanes(pd, entity, input)
    local check = pd.checked[input.unit_number]
    local lanes = {}
    if get_belt_type(input) == 'splitter' then
        for _, side_check in pairs(check) do
            get_input_paths(side_check, lanes)
        end
    else
        get_input_paths(check, lanes)
    end
    return lanes
end
local default_output = { 'output', 'output' }
local function get_output_lanes(pd, entity, lanes, output)
    if not output or entity.direction == output.direction then return lanes, default_output end
    if not pd.ghost and output.type == 'entity-ghost' then return lanes, default_output end
    local clockwise = is_clockwise(entity, output)
    local next_lanes = {}
    local offsets = {}
    if get_belt_type(output) == 'underground-belt' then
        for lane in pairs(lanes) do
            local is_input = output.belt_to_ground_type == 'input'
            if (clockwise == is_input) == (lane == 1) then
                next_lanes[clockwise and 2 or 1] = true
                offsets[lane] = 'sideload'
            else
                offsets[lane] = 'output'
            end
        end
    else
        if #output.belt_neighbours.inputs ~= 1 then
            for lane in pairs(lanes) do
                next_lanes[clockwise and 2 or 1] = true
                offsets[lane] = 'sideload'
            end
        else
            return lanes, default_output
        end
    end
    return next_lanes, offsets
end
local function get_prev_lanes(entity, lanes, input)
    if entity.direction == input.direction then return lanes end
    local clockwise = is_clockwise(input, entity)
    for lane in pairs(lanes) do
        if clockwise == (lane == 2) then
            if get_belt_type(entity) == 'underground-belt' then
                local btg_type = entity.belt_to_ground_type == 'input'
                return lane_cycle[clockwise == btg_type and 2 or 3]
            else
                return lane_cycle[1]
            end
        end
    end
end
local function add_to_queue(pd, entity, lanes, path, old_entity)
    if not entity then return end
    local belt_type = entity.type
    if belt_type == 'entity-ghost' then
        if pd.ghost then
            belt_type = entity.ghost_type
        else return end
    end
    local is_splitter = belt_type == 'splitter'
    local sides
    if is_splitter then
        local const_sides = get_splitter_sides(entity, old_entity)
        sides = {}
        for side in pairs(const_sides) do
            sides[side] = true
        end
        if path == 2 then
            local filter_side = get_filter_side(pd, entity)
            if filter_side then
                for side in pairs(const_sides) do
                    if filter_side ~= side then
                        sides[side] = nil
                    end
                end
                if not next(sides) then return end
            end
        end
    end
    local unit_number = entity.unit_number
    local checked = pd.checked
    local new_lanes = {}
    for lane in pairs(lanes) do
        local check
        if checked[unit_number] then
            if is_splitter then
                for side in pairs(sides) do
                    check = checked[unit_number][side][lane][path]
                end
            else
                check = checked[unit_number][lane][path]
            end
        else
            checked[unit_number] = empty_check(belt_type)
        end
        if not check then
            new_lanes[lane] = true
            check_entity(pd, unit_number, lane, path, sides)
        end
    end
    if next(new_lanes) then
        local next_entities = pd.next_entities
        local next_len = pd.next_len + 1
        pd.next_len = next_len
        next_entities[next_len] = { entity = entity, lanes = new_lanes, path = path }
    end
end
local highlight_entity = {}
highlight_entity['transport-belt'] = function(pd, entity, lanes, path)
    local direction = entity.direction
    local belt_neighbours = entity.belt_neighbours
    local inputs = belt_neighbours.inputs
    local output = belt_neighbours.outputs[1]
    local is_curved = entity.belt_shape ~= 'straight'
    local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, output)
    for lane in pairs(lanes) do
        local offsets = straight[lane][direction]
        local lane_offset = lane_offsets[lane]
        if not is_curved then
            draw.line(pd, entity, offsets.input, offsets[lane_offset])
        else
            draw.arc(pd, entity, lane, entity.belt_shape == 'right')
            if lane_offset == 'sideload' then
                draw.line(pd, entity, offsets.output, offsets[lane_offset])
            end
        end
    end
    if path == 1 then
        add_to_queue(pd, output, next_lanes, 1, entity)
    else
        for _, input in pairs(inputs) do
            local prev_lanes = is_curved and lanes or get_prev_lanes(entity, lanes, input)
            if prev_lanes then add_to_queue(pd, input, prev_lanes, 2, entity) end
        end
    end
end
highlight_entity['underground-belt'] = function(pd, entity, lanes, path)
    local direction = entity.direction
    local belt_neighbours = entity.belt_neighbours
    local output = belt_neighbours.outputs[1]
    local btg_type = entity.belt_to_ground_type
    local is_input = btg_type == 'input'
    local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, output)
    for lane in pairs(lanes) do
        local lane_offset = is_input and 'input' or lane_offsets[lane]
        draw.line(pd, entity, underground[lane][direction][btg_type], straight[lane][direction][lane_offset])
    end
    local forward = path == 1
    if forward then
        add_to_queue(pd, output, next_lanes, path, entity)
    else
        for _, input in pairs(belt_neighbours.inputs) do
            local prev_lanes = get_prev_lanes(entity, lanes, input)
            if prev_lanes then add_to_queue(pd, input, prev_lanes, path, entity) end
        end
    end
    local neighbour = entity.underground_belt_neighbour
    if neighbour and forward == is_input then
        local check = pd.checked[entity.unit_number]
        local neighbour_check = pd.checked[neighbour.unit_number]
        for lane in pairs(lanes) do
            if not (neighbour_check and neighbour_check[lane].dash) then
                local offsets = dash[lane][direction]
                local from = is_input and entity or neighbour
                local to = is_input and neighbour or entity
                draw.dash(pd, from, to, offsets.input, offsets.output)
            end
            check[lane].dash = true
        end
        add_to_queue(pd, neighbour, lanes, path, entity)
    end
end
highlight_entity['splitter'] = function(pd, entity, lanes, path)
    local direction = entity.direction
    local belt_neighbours = entity.belt_neighbours
    local forward = path == 1
    local belts = {}
    for _, belt in pairs(belt_neighbours[forward and 'outputs' or 'inputs']) do
        for side in pairs(get_splitter_sides(entity, belt)) do
            if forward or get_belt_type(belt) ~= 'splitter' or get_filter_side(pd, belt) ~= side then
                belts[side] = belt
            end
        end
    end
    local queued
    local filter_side = get_filter_side(pd, entity)
    for side in pairs(forward and side_cycle[filter_side] or side_cycle.both) do
        local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, belts[side])
        for lane in pairs(lanes) do
            local offsets = splitter[lane][direction]
            local side_offsets = offsets[side]
            local lane_offset = forward and lane_offsets[lane] or 'input'
            draw.line(pd, entity, side_offsets.middle, side_offsets[lane_offset])
            draw.line(pd, entity, offsets.left.line, offsets.right.line)
        end
        if queued ~= belts[side] then
            add_to_queue(pd, belts[side], next_lanes, path, entity)
            queued = belts[side]
        end
    end
    for _, belt in pairs(belt_neighbours[forward and 'inputs' or 'outputs']) do
        local belt_check = pd.checked[belt.unit_number]
        if belt_check then
            local checked_lanes = forward and get_input_lanes(pd, entity, belt) or lanes
            local _, lane_offsets = get_output_lanes(pd, entity, lanes, belt)
            local sides = not forward and side_cycle[filter_side] or get_splitter_sides(entity, belt)
            for side in pairs(sides) do
                for lane in pairs(checked_lanes) do
                    local belt_path
                    if get_belt_type(belt) == 'splitter' then
                        belt_path = belt_check.left[lane][path] or belt_check.right[lane][path]
                    else
                        belt_path = belt_check[lane][path]
                    end
                    if belt_path then
                        local side_offsets = splitter[lane][direction][side]
                        local lane_offset = forward and 'input' or lane_offsets[lane]
                        draw.line(pd, entity, side_offsets.middle, side_offsets[lane_offset])
                    end
                end
            end
        end
    end
end
highlight_entity['lane-splitter'] = function(pd, entity, lanes, path)
    local direction = entity.direction
    local belt_neighbours = entity.belt_neighbours
    local input = belt_neighbours.inputs[1]
    local output = belt_neighbours.outputs[1]
    local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, output)
    for lane in pairs(lanes) do
        local offsets = lane_splitter[lane][direction]
        local lane_offset = lane_offsets[lane]
        draw.line(pd, entity, offsets.input, offsets[lane_offset])
    end
    if path == 1 then
        add_to_queue(pd, output, next_lanes, 1, entity)
    else
        if input then
            local prev_lanes = get_prev_lanes(entity, lanes, input)
            if prev_lanes then add_to_queue(pd, input, prev_lanes, 2, entity) end
        end
    end
end
highlight_entity['linked-belt'] = function(pd, entity, lanes, path)
    local direction = entity.direction
    local belt_neighbours = entity.belt_neighbours
    local output = belt_neighbours.outputs[1]
    local linked_belt_neighbour = entity.linked_belt_neighbour
    local is_input = entity.linked_belt_type == 'input'
    local forward = path == 1
    local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, output)
    for lane in pairs(lanes) do
        local offsets = linked_belt[lane][direction]
        local middle = offsets.middle
        local lane_offset = is_input and 'input' or lane_offsets[lane]
        draw.line(pd, entity, middle, offsets[lane_offset])
        draw.circle(pd, entity, middle)
    end
    add_to_queue(pd, forward and output or belt_neighbours.inputs[1], next_lanes, path, entity)
    if is_input == forward then
        add_to_queue(pd, linked_belt_neighbour, lanes, path, entity)
    end
end
local function highlight_loader(loader_const)
    return function(pd, entity, lanes, path)
        local direction = entity.direction
        local belt_neighbours = entity.belt_neighbours
        local output = belt_neighbours.outputs[1]
        local loader_type = entity.loader_type
        local next_lanes, lane_offsets = get_output_lanes(pd, entity, lanes, output)
        for lane in pairs(lanes) do
            local offsets = loader_const[lane][direction]
            local lane_offset = lane_offsets[lane]
            draw.line(pd, entity, offsets.input, offsets[lane_offset])
            draw.rectangle(pd, entity, loader_const.rectangle[lane][direction][loader_type])
        end
        local forward = path == 1
        local new_entity = forward and output or belt_neighbours.inputs[1]
        add_to_queue(pd, new_entity, next_lanes, path, entity)
        if entity.type == 'entity-ghost' then return end 
        if CONTAINER_PASSTHROUGH and forward == (loader_type == 'input') then
            local container = entity.loader_container
            if container and (container.type == 'container' or container.type == 'logistic-container'
                    or container.type == 'infinity-container') then
                local box = container.prototype.collision_box
                local lt, rb = box.left_top, box.right_bottom
                local pos = container.position
                local loaders = container.surface.find_entities_filtered{
                    area = { { pos.x + lt.x - 1, pos.y + lt.y - 1 }, { pos.x + rb.x + 1, pos.y + rb.y + 1 } },
                    type = { 'loader', 'loader-1x1' },
                }
                for _, other in pairs(loaders) do
                    local other_container = other.loader_container
                    if other ~= entity and other_container and other_container == container
                        and loader_type ~= other.loader_type then
                        add_to_queue(pd, other, lane_cycle[1], path, entity)
                    end
                end
            end
        end
    end
end
highlight_entity['loader'] = highlight_loader(loader)
highlight_entity['loader-1x1'] = highlight_loader(loader_1x1)
return highlight_entity
