local Config = require 'lib.config'
local CAR_FINDER_TOGGLE_ID = 'car_finder'
local SHOW_COLORS       = true   
local SHOW_DISTANCE     = true   
local SHOW_COORDINATES  = true   
local SHOW_ENTITY_NAMES = false  
local FOCUS_LINKED_REMOTE = true 
local MAX_RESULTS = 30           
local CarFinder = {}
local function round(v)
    return v and math.floor(v + 0.5)
end
local COMPASS_KEYS = {
    'east', 'southeast', 'south', 'southwest',
    'west', 'northwest', 'north', 'northeast'
}
local function compass_direction(dx, dy)
    if dx == 0 and dy == 0 then return nil end
    local angle = math.deg(math.atan2(dy, dx))
    local index = math.floor(((angle + 22.5) % 360) / 45)
    return COMPASS_KEYS[index + 1]
end
local function heading(pos_from, pos_to)
    if not (pos_from and pos_to) then
        return { distance = nil, direction = nil }
    end
    local dx = pos_to.x - pos_from.x
    local dy = pos_to.y - pos_from.y
    return {
        distance = math.sqrt(dx * dx + dy * dy),
        direction = compass_direction(dx, dy)
    }
end
local function find_vehicle_info(player, entity)
    return {
        entity = entity,
        heading = heading(player.position, entity.position),
        localised_name_token = (entity.prototype and entity.prototype.localised_name) or entity.name
    }
end
local function find_vehicle_infos(player)
    local vehicles = player.surface.find_entities_filtered({
        type = { 'car', 'spider-vehicle' },
        force = player.force.name,
    })
    local infos = {}
    for _, entity in pairs(vehicles) do
        infos[#infos + 1] = find_vehicle_info(player, entity)
    end
    table.sort(infos, function(a, b)
        return (a.heading.distance or 0) < (b.heading.distance or 0)
    end)
    return infos
end
local function print_vehicle_summary(player, vehicle_info)
    local entity = vehicle_info.entity
    local h = vehicle_info.heading
    local parts = { '', '[img=entity/' .. entity.name .. '] ' }
    if SHOW_COLORS and entity.color and entity.color.a > 0 then
        local r = round(255 * entity.color.r)
        local g = round(255 * entity.color.g)
        local b = round(255 * entity.color.b)
        parts[#parts + 1] = '[color=' .. r .. ',' .. g .. ',' .. b .. ']'
        parts[#parts + 1] = vehicle_info.localised_name_token
        parts[#parts + 1] = '[/color]'
    else
        parts[#parts + 1] = vehicle_info.localised_name_token
    end
    if SHOW_ENTITY_NAMES then
        parts[#parts + 1] = ' (' .. entity.name .. ')'
    end
    if SHOW_DISTANCE or SHOW_COORDINATES then
        parts[#parts + 1] = ' '
        parts[#parts + 1] = { 'fp-car-finder.is-at' }
        parts[#parts + 1] = ' '
        if SHOW_DISTANCE then
            parts[#parts + 1] = (round(h.distance) or '?') .. 'm '
            parts[#parts + 1] = h.direction
                and { 'fp-car-finder.' .. h.direction }
                or { 'fp-car-finder.away' }
            parts[#parts + 1] = ' '
        end
        if SHOW_COORDINATES then
            local gps = ' [gps=' .. round(entity.position.x) .. ',' .. round(entity.position.y)
            if entity.surface and entity.surface.name and entity.surface.name ~= 'nauvis' then
                gps = gps .. ',' .. entity.surface.name
            end
            gps = gps .. ']'
            parts[#parts + 1] = gps
        end
    end
    player.print(parts)
end
local function print_all_vehicles(player)
    local infos = find_vehicle_infos(player)
    player.print({ 'fp-car-finder.notify-searching' })
    local count = math.min(#infos, MAX_RESULTS)
    for i = 1, count do
        print_vehicle_summary(player, infos[i])
    end
    if count == 0 then
        player.print({ 'fp-car-finder.result-none' })
    elseif #infos > MAX_RESULTS then
        player.print({ 'fp-car-finder.result-overflow' })
    end
end
local function maybe_focus_linked_spidertron(player)
    if not FOCUS_LINKED_REMOTE then return false end
    local entities = player.spidertron_remote_selection
    if not entities or #entities == 0 then return false end
    local vehicle = entities[1]
    if not (vehicle and vehicle.valid and vehicle.surface == player.surface) then
        return false
    end
    player.print({ 'fp-car-finder.result-spider-focus' })
    print_vehicle_summary(player, find_vehicle_info(player, vehicle))
    player.set_controller({
        type = defines.controllers.remote,
        position = vehicle.position,
        surface = vehicle.surface,
    })
    return true
end
function CarFinder.is_enabled()
    return Config.is_enabled(CAR_FINDER_TOGGLE_ID)
end
function CarFinder.activate(player)
    if not (player and player.valid and player.surface) then return end
    if not CarFinder.is_enabled() then return end
    local focused = maybe_focus_linked_spidertron(player)
    if not focused then
        print_all_vehicles(player)
    end
end
return CarFinder
