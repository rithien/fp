local abs = math.abs
local sqrt = math.sqrt
local acos = math.acos
local round_up = math.ceil
local full_circle_in_radians = math.pi * 2
local item_size_on_belt = 0.25 
local inserter_angle_precision = 0.001 
local function get_belt_penalty(belt_speed, stack_size)
    local penalty = 0
    stack_size = stack_size - 1
    local item_center_offset = belt_speed
    local acted = true
    while stack_size > 0 do
        if item_center_offset > 0 then
            stack_size = stack_size - 1
            item_center_offset = item_center_offset - item_size_on_belt
            acted = true
        end
        item_center_offset = item_center_offset + belt_speed
        if not acted and (item_center_offset > 0) then
            stack_size = stack_size - 1
            item_center_offset = item_center_offset - item_size_on_belt
            acted = true
        end
        penalty = penalty + 1
        acted = false
    end
    return penalty
end
local function calc(rotation_speed, extension_speed, pickup_vector, drop_vector, stack_size, pickup_belt_speed, drop_belt_speed)
    local pickup_x, pickup_y = pickup_vector[1], pickup_vector[2]
    local drop_x, drop_y = drop_vector[1], drop_vector[2]
    local pickup_length = sqrt(pickup_x * pickup_x + pickup_y * pickup_y)
    local drop_length = sqrt(drop_x * drop_x + drop_y * drop_y)
    local angle = 0
    if pickup_length > 0 and drop_length > 0 then
        local ratio = (pickup_x * drop_x + pickup_y * drop_y) / (pickup_length * drop_length)
        if ratio > 1 then ratio = 1
        elseif ratio < -1 then ratio = -1 end
        angle = acos(ratio)
    end
    angle = angle / full_circle_in_radians - inserter_angle_precision
    local ticks_per_cycle = 2 * round_up(angle / rotation_speed)
    local extension_time = 2 * round_up(abs(pickup_length - drop_length) / extension_speed)
    if ticks_per_cycle < extension_time then
        ticks_per_cycle = extension_time
    end
    if ticks_per_cycle < 2 then
        ticks_per_cycle = 2
    end
    if pickup_belt_speed and (stack_size > 1) then
        ticks_per_cycle = ticks_per_cycle + get_belt_penalty(pickup_belt_speed, stack_size)
    end
    if drop_belt_speed and (stack_size > 1) then
        ticks_per_cycle = ticks_per_cycle + get_belt_penalty(drop_belt_speed, stack_size)
    end
    if drop_belt_speed then
        local max = drop_belt_speed * ticks_per_cycle * 4
        if stack_size > max then stack_size = max end
    end
    if pickup_belt_speed then
        local max = pickup_belt_speed * ticks_per_cycle * 8
        if stack_size > max then stack_size = max end
    end
    return stack_size * 60 / ticks_per_cycle 
end
return calc
