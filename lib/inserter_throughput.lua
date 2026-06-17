local Event = require 'lib.event'
local Config = require 'lib.config'
local calc = require 'lib.inserter_throughput.calc'
local de = defines.events
local TOGGLE_ID = 'inserter_throughput'
local TEXT_COLOR = { 1, 1, 1 }
local TEXT_OFFSET = { 0.5, -0.5 } 
local ROUNDING_PRECISION = 2
local strlen = string.len
local format = string.format
local Public = {}
local function vector(from, to)
    return { to.x - from.x, to.y - from.y }
end
local function number_to_string_with_precision(number, precision)
    local result = tostring(number)
    if precision > 0 then
        local rounded = format(format('%%.%if', precision), number)
        if strlen(rounded) < strlen(result) then
            result = rounded
        end
    end
    return result
end
local function get_stack_size(inserter, prototype)
    local stack_size = inserter.inserter_stack_size_override
    if stack_size > 0 then
        return stack_size
    end
    if prototype.bulk then
        return 1 + prototype.inserter_stack_size_bonus + inserter.force.bulk_inserter_capacity_bonus
    end
    return 1 + prototype.inserter_stack_size_bonus + inserter.force.inserter_stack_size_bonus
end
local function get_throughput_info(inserter, precision)
    local inserter_position = inserter.position
    local prototype = (inserter.type == 'entity-ghost'
        and inserter.ghost_prototype or inserter.prototype)
    local pickup_position = inserter.pickup_position
    local pickup_target = inserter.pickup_target
    if not pickup_target then
        pickup_target = inserter.surface.find_entities_filtered{
            position = pickup_position, limit = 1 }[1]
    end
    local pickup_belt_speed
    if pickup_target then
        if pickup_target.type == 'entity-ghost' then
            pickup_belt_speed = pickup_target.ghost_prototype.belt_speed
        else
            pickup_belt_speed = pickup_target.prototype.belt_speed
        end
    end
    local drop_position = inserter.drop_position
    local drop_target = inserter.drop_target
    if not drop_target then
        drop_target = inserter.surface.find_entities_filtered{
            position = drop_position, limit = 1 }[1]
    end
    local drop_belt_speed
    if drop_target then
        if drop_target.type == 'entity-ghost' then
            drop_belt_speed = drop_target.ghost_prototype.belt_speed
        else
            drop_belt_speed = drop_target.prototype.belt_speed
        end
    end
    local quality = inserter.quality
    local value = calc(
        prototype.get_inserter_rotation_speed(quality),
        prototype.get_inserter_extension_speed(quality),
        vector(inserter_position, pickup_position),
        vector(inserter_position, drop_position),
        get_stack_size(inserter, prototype),
        pickup_belt_speed,
        drop_belt_speed
    )
    return { '', number_to_string_with_precision(value, precision), { 'per-second-suffix' } }
end
local function ensure_storage()
    if not storage.inserter_throughput then
        storage.inserter_throughput = { players = {}, user_disabled = {} }
    else
        if not storage.inserter_throughput.players then storage.inserter_throughput.players = {} end
        if not storage.inserter_throughput.user_disabled then storage.inserter_throughput.user_disabled = {} end
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function pdata(index)
    ensure_storage()
    local players = storage.inserter_throughput.players
    local pd = players[index]
    if not pd then
        pd = { text_object = nil }
        players[index] = pd
    end
    return pd
end
local function clear_player(index)
    ensure_storage()
    local pd = storage.inserter_throughput.players[index]
    if not pd then return end
    local obj = pd.text_object
    if obj and obj.valid then
        obj.destroy()
    end
    pd.text_object = nil
end
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    ensure_storage()
    return not storage.inserter_throughput.user_disabled[index]
end
function Public.toggle_user(index)
    ensure_storage()
    local disabled = storage.inserter_throughput.user_disabled
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
    for index in pairs(storage.inserter_throughput.players) do
        clear_player(index)
    end
end
local function is_inserter(entity)
    if not entity or not entity.valid then return false end
    if entity.type == 'inserter' then return true end
    if entity.type == 'entity-ghost' and entity.ghost_type == 'inserter' then return true end
    return false
end
local function on_selected(event)
    local index = event.player_index
    clear_player(index)
    if not Public.is_active_for(index) then return end
    local player = game.get_player(index)
    if not player then return end
    local selected = player.selected
    if not is_inserter(selected) then return end
    pdata(index).text_object = rendering.draw_text{
        text = get_throughput_info(selected, ROUNDING_PRECISION),
        surface = selected.surface,
        target = { entity = selected, offset = TEXT_OFFSET },
        scale = player.display_scale,
        color = TEXT_COLOR,
        players = { index },
        scale_with_zoom = true,
        vertical_alignment = 'baseline',
    }
end
Event.add(de.on_selected_entity_changed, on_selected)
Event.add(de.on_player_left_game, function(event)
    clear_player(event.player_index)
    if storage.inserter_throughput and storage.inserter_throughput.players then
        storage.inserter_throughput.players[event.player_index] = nil
    end
end)
return Public
