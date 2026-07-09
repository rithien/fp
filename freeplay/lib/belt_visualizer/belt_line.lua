local utils = require 'lib.belt_visualizer.utils'
local get_belt_type = utils.get_belt_type
local function switch(t, case, ...)
    local fun = t[case]
    if fun then
        return fun(...)
    end
end
local next_switch = {
    ['transport-belt'] = function(entity)
        return entity.belt_neighbours.outputs[1]
    end,
    ['underground-belt'] = function(entity)
        if entity.belt_to_ground_type == 'input' then
            return entity.underground_belt_neighbour
        else
            return entity.belt_neighbours.outputs[1]
        end
    end,
    ['linked-belt'] = function(entity)
        if entity.linked_belt_type == 'input' then
            return entity.linked_belt_neighbour
        else
            return entity.belt_neighbours.outputs[1]
        end
    end,
}
local previous_switch = {
    ['transport-belt'] = function(entity)
        return entity.belt_neighbours.inputs[1]
    end,
    ['underground-belt'] = function(entity)
        if entity.belt_to_ground_type == 'output' then
            return entity.underground_belt_neighbour
        else
            return entity.belt_neighbours.inputs[1]
        end
    end,
    ['linked-belt'] = function(entity)
        if entity.linked_belt_type == 'output' then
            return entity.linked_belt_neighbour
        else
            return entity.belt_neighbours.inputs[1]
        end
    end,
}
local function walk_belt(belt, belt_switch, belt_line, max_steps, ghost, include)
    local c = 0
    while c < max_steps do
        if not belt then return end
        if belt.type == 'entity-ghost' and not ghost then return end
        local belt_type = get_belt_type(belt)
        if belt_type == 'splitter' then return end
        if include then
            belt_line[belt.unit_number] = true
        end
        local limit = 1
        if (belt_type == 'underground-belt' and belt.belt_to_ground_type == 'output')
            or (belt_type == 'linked-belt' and belt.linked_belt_type == 'output') then
            limit = 0
        end
        if #belt.belt_neighbours.inputs > limit then return end
        belt_line[belt.unit_number] = true
        belt = switch(belt_switch, belt_type, belt)
        c = c + 1
    end
    return belt
end
local Public = {}
function Public.cache_belt_line(pd, max_steps)
    local head, tail = pd.head, pd.tail
    local belt_line = pd.belt_line
    if not belt_line then return end
    local ghost = pd.ghost
    if head and head.valid then
        head = switch(next_switch, get_belt_type(head), head)
        pd.head = walk_belt(head, next_switch, belt_line, max_steps, ghost)
    end
    if tail and tail.valid then
        pd.tail = walk_belt(tail, previous_switch, belt_line, max_steps, ghost, true)
    end
end
return Public
