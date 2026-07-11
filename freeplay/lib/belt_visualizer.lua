local Event = require 'lib.event'
local Config = require 'lib.config'
local const = require 'lib.belt_visualizer.constants'
local utils = require 'lib.belt_visualizer.utils'
local highlight_entity = require 'lib.belt_visualizer.highlight'
local BeltLine = require 'lib.belt_visualizer.belt_line'
local de = defines.events
local TOGGLE_ID = 'belt_visualizer'
local OPS_PER_TICK = 64    
local MAX_OPS = 1500       
local CLEARS_PER_TICK = 512 
local REFRESH_DELAY = 60   
local get_belt_type = utils.get_belt_type
local connectables = const.connectables
local LANES = const.lane_cycle[1] 
local side_cycle = const.side_cycle
local Public = {}
local function ensure_storage()
    if not storage.belt_visualizer then
        storage.belt_visualizer = {
            players = {},      
            user_enabled = {}, 
            in_progress = {},  
            refresh = {},      
            clear = {},        
        }
    else
        local bv = storage.belt_visualizer
        bv.players = bv.players or {}
        bv.user_enabled = bv.user_enabled or {}
        bv.user_disabled = nil
        bv.in_progress = bv.in_progress or {}
        bv.refresh = bv.refresh or {}
        bv.clear = bv.clear or {}
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function pdata(index)
    ensure_storage()
    local players = storage.belt_visualizer.players
    local pd = players[index]
    if not pd then
        pd = { index = index, ghost = true }
        players[index] = pd
    end
    return pd
end
local function clear_player(index, keep_origin)
    ensure_storage()
    local bv = storage.belt_visualizer
    bv.in_progress[index] = nil
    bv.refresh[index] = nil
    local pd = bv.players[index]
    if not pd then return end
    pd.checked = nil
    pd.belt_line = nil
    pd.drawn_offsets = nil
    pd.drawn_arcs = nil
    pd.head = nil
    pd.tail = nil
    pd.next_entities = nil
    pd.ops = nil
    if not keep_origin then
        pd.origin = nil
    end
    if pd.render then
        local clear_list = bv.clear
        local n = #clear_list
        for _, render in pairs(pd.render) do
            n = n + 1
            clear_list[n] = render
        end
    end
    pd.render = nil
end
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    ensure_storage()
    return storage.belt_visualizer.user_enabled[index] == true
end
function Public.toggle_user(index)
    ensure_storage()
    local enabled = storage.belt_visualizer.user_enabled
    if enabled[index] then
        enabled[index] = nil
        clear_player(index)
    else
        enabled[index] = true
    end
    return enabled[index] == true
end
function Public.is_active_for(index)
    return Config.is_enabled(TOGGLE_ID) and Public.is_user_enabled(index)
end
function Public.clear_all()
    ensure_storage()
    for index in pairs(storage.belt_visualizer.players) do
        clear_player(index)
    end
end
local function seed(pd, selected)
    local belt_type = get_belt_type(selected)
    local unit_number = selected.unit_number
    pd.origin = selected
    pd.drawn_offsets = {}
    pd.drawn_arcs = {}
    pd.checked = { [unit_number] = utils.empty_check(belt_type) }
    pd.belt_line = {}
    pd.head = selected
    pd.tail = selected
    pd.next_entities = {}
    pd.next_index = 1
    pd.next_len = 2
    pd.render = {}
    pd.ops = 0
    for path = 1, 2 do
        pd.next_entities[path] = { entity = selected, lanes = LANES, path = path }
        local sides = belt_type == 'splitter' and side_cycle.both
        for lane in pairs(LANES) do
            utils.check_entity(pd, unit_number, lane, path, sides)
        end
    end
    storage.belt_visualizer.in_progress[pd.index] = true
end
local function start_highlight(index, player, selected)
    local pd = pdata(index)
    pd.filter = utils.get_cursor_name(player)
    seed(pd, selected)
end
local function refresh_player(index)
    local bv = storage.belt_visualizer
    local pd = bv.players[index]
    if not pd then return end
    local origin = pd.origin
    clear_player(index)
    if not (origin and origin.valid) then return end
    if not Public.is_active_for(index) then return end 
    seed(pd, origin)
end
local function on_selected(event)
    local index = event.player_index
    ensure_storage()
    local player = game.get_player(index)
    if not player then return end
    local selected = player.selected
    if Public.is_active_for(index) and selected and selected.unit_number then
        local belt_type = get_belt_type(selected)
        if connectables[belt_type] then
            local pd = storage.belt_visualizer.players[index]
            if pd and pd.belt_line and pd.belt_line[selected.unit_number] then
                pd.origin = selected
                return
            end
            clear_player(index)
            start_highlight(index, player, selected)
            return
        end
    end
    clear_player(index)
end
local function highlightable(pd, entity)
    local checked = pd.checked
    if not checked then return false end
    if checked[entity.unit_number] then return true end
    local neighbours = entity.belt_neighbours
    for _, input in pairs(neighbours.inputs) do
        if checked[input.unit_number] then return true end
    end
    for _, output in pairs(neighbours.outputs) do
        if checked[output.unit_number] then return true end
    end
    local etype = entity.type
    if etype == 'underground-belt' then
        local neighbour = entity.underground_belt_neighbour
        if neighbour and checked[neighbour.unit_number] then return true end
    elseif etype == 'linked-belt' then
        local neighbour = entity.linked_belt_neighbour
        if neighbour and checked[neighbour.unit_number] then return true end
    end
    return false
end
local function on_entity_modified(event)
    local entity = event.entity or event.destination
    if not (entity and entity.valid and connectables[entity.type]) then return end
    local bv = storage.belt_visualizer
    if not bv or not next(bv.players) then return end
    local refresh = bv.refresh
    for index, pd in pairs(bv.players) do
        if not refresh[index] and highlightable(pd, entity) then
            refresh[index] = event.tick + REFRESH_DELAY
        end
    end
end
local function drain(event)
    local bv = storage.belt_visualizer
    if not bv then return end
    local clear_list = bv.clear
    local refresh = bv.refresh
    local in_progress = bv.in_progress
    if not (clear_list[1] or next(refresh) or next(in_progress)) then return end
    local tick = event.tick
    for index, due in pairs(refresh) do
        if tick >= due then
            refresh[index] = nil
            refresh_player(index)
        end
    end
    local n = #clear_list
    if n > 0 then
        local stop = n - CLEARS_PER_TICK + 1
        if stop < 1 then stop = 1 end
        for i = n, stop, -1 do
            local render = clear_list[i]
            if render.valid then render.destroy() end
            clear_list[i] = nil
        end
    end
    for index in pairs(in_progress) do
        local pd = bv.players[index]
        if not (pd and pd.next_entities) then
            in_progress[index] = nil
        else
            BeltLine.cache_belt_line(pd, OPS_PER_TICK)
            local c = 0
            while c < OPS_PER_TICK do
                local next_index = pd.next_index
                local next_data = pd.next_entities[next_index]
                if not next_data then break end
                local entity = next_data.entity
                if entity.valid then
                    highlight_entity[get_belt_type(entity)](pd, entity, next_data.lanes, next_data.path)
                    c = c + 1
                end
                pd.next_entities[next_index] = nil
                pd.next_index = next_index + 1
            end
            pd.ops = pd.ops + c
            if not pd.next_entities[pd.next_index] then
                in_progress[index] = nil
            elseif pd.ops >= MAX_OPS then
                in_progress[index] = nil
                pd.next_entities = {} 
                pd.next_index = 1
                pd.next_len = 0
            end
        end
    end
end
Event.add(de.on_selected_entity_changed, on_selected)
Event.on_nth_tick(1, drain)
Event.add(de.on_built_entity, on_entity_modified)
Event.add(de.on_robot_built_entity, on_entity_modified)
Event.add(de.on_entity_cloned, on_entity_modified)
Event.add(de.script_raised_built, on_entity_modified)
Event.add(de.script_raised_revive, on_entity_modified)
Event.add(de.on_player_mined_entity, on_entity_modified)
Event.add(de.on_robot_mined_entity, on_entity_modified)
Event.add(de.script_raised_destroy, on_entity_modified)
Event.add(de.on_entity_died, on_entity_modified)
Event.add(de.on_player_rotated_entity, function(event)
    local entity = event.entity
    if not (entity and entity.valid and connectables[entity.type]) then return end
    on_entity_modified(event)
    local neighbour = entity.type == 'underground-belt' and entity.underground_belt_neighbour
        or entity.type == 'linked-belt' and entity.linked_belt_neighbour
    if neighbour then
        on_entity_modified{ entity = neighbour, tick = event.tick }
    end
end)
local function remove_player(event)
    local index = event.player_index
    clear_player(index)
    if storage.belt_visualizer then
        storage.belt_visualizer.players[index] = nil
    end
end
Event.add(de.on_player_left_game, remove_player)
Event.add(de.on_player_removed, remove_player)
return Public
