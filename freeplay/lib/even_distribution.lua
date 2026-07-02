local Event = require 'lib.event'
local Config = require 'lib.config'
local AntigriefCore = require 'lib.antigrief.core'
local AdminPresence = require 'lib.antigrief.admin_presence'
local de = defines.events
local TOGGLE_ID = 'even_distribution'
local DELAY_TICKS = 30
local SNAP_WINDOW = 90
local IGNORED_TYPES = {
    ['transport-belt'] = true,
    ['underground-belt'] = true,
    ['splitter'] = true,
    ['loader'] = true,
    ['loader-1x1'] = true,
    ['logistic-robot'] = true,
    ['construction-robot'] = true,
    ['character'] = true,
}
local FLY_COLOR = { r = 1, g = 1, b = 0.5 }
local Public = {}
local function ensure_storage()
    if not storage.even_distribution then
        storage.even_distribution = { cache = {}, distrEvents = {}, user_disabled = {} }
    elseif not storage.even_distribution.user_disabled then
        storage.even_distribution.user_disabled = {} 
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function get_cache(index)
    ensure_storage()
    local c = storage.even_distribution.cache[index]
    if not c then
        c = { entities = {}, itemCount = 0, cursorStackCount = 0 }
        storage.even_distribution.cache[index] = c
    end
    return c
end
local function reset_cache(cache)
    cache.entities = {}
    cache.item = nil
    cache.itemCount = 0
    cache.cursorStackCount = 0
    cache.applyTick = nil
    cache.selectedEvent = nil
end
local function is_user_enabled(index)
    ensure_storage()
    return not storage.even_distribution.user_disabled[index]
end
local function is_active_for(index)
    return Config.is_enabled(TOGGLE_ID) and is_user_enabled(index)
end
local function is_eligible(entity, item)
    if not entity or not entity.valid then return false end
    if IGNORED_TYPES[entity.type] then return false end
    return entity.can_insert({ name = item, count = 1 })
end
local function blocked_by_antigrief(player, entity)
    return AntigriefCore.should_hard_block(player, entity) and not AdminPresence.is_permissive()
end
local function count_player_items(player, item)
    local total = 0
    local inv = player.get_main_inventory()
    if inv then total = inv.get_item_count(item) end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == item then
        total = total + cursor.count
    end
    return total
end
local function take_from_player(player, item, amount)
    if amount <= 0 then return 0 end
    local taken = 0
    local inv = player.get_main_inventory()
    if inv then
        taken = inv.remove({ name = item, count = amount })
    end
    if taken < amount then
        local cursor = player.cursor_stack
        if cursor and cursor.valid_for_read and cursor.name == item then
            local from_cursor = math.min(amount - taken, cursor.count)
            cursor.count = cursor.count - from_cursor 
            taken = taken + from_cursor
        end
    end
    return taken
end
local function return_to_player(player, item, amount)
    if amount <= 0 then return end
    local inserted = player.insert({ name = item, count = amount }) or 0
    local remainder = amount - inserted
    if remainder > 0 then
        player.surface.spill_item_stack({
            position = player.position,
            stack = { name = item, count = remainder },
            enable_looted = true,
            force = player.force,
            allow_belts = false,
        })
    end
end
local function give_back(entity, player, cache)
    local item = cache.item
    if not item then return end
    local collected = 0
    if cache.itemCount > 0 then
        collected = entity.remove_item({ name = item, count = cache.itemCount })
    end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name ~= item then
        return_to_player(player, item, collected)
        return
    end
    local have = collected + ((cursor and cursor.valid_for_read) and cursor.count or 0)
    if have <= 0 then return end
    local to_cursor = math.min(have, cache.cursorStackCount)
    if to_cursor > 0 then
        cursor.set_stack({ name = item, count = to_cursor })
    elseif cursor and cursor.valid_for_read then
        cursor.clear()
    end
    local leftover = have - to_cursor
    if leftover > 0 then
        return_to_player(player, item, leftover)
    end
end
local function register_distr(player, cache)
    local q = storage.even_distribution.distrEvents
    if cache.applyTick and q[cache.applyTick] then
        q[cache.applyTick][player.index] = nil
    end
    cache.applyTick = game.tick + DELAY_TICKS
    q[cache.applyTick] = q[cache.applyTick] or {}
    q[cache.applyTick][player.index] = cache
end
local function already_listed(cache, entity)
    for _, e in ipairs(cache.entities) do
        if e == entity then return true end
    end
    return false
end
local function distribute(player, cache)
    local item = cache.item
    if not item then return end
    local ents = {}
    for _, e in ipairs(cache.entities) do
        if e and e.valid then ents[#ents + 1] = e end
    end
    local n = #ents
    if n == 0 then return end
    local total = count_player_items(player, item)
    if total <= 0 then return end
    local base = math.floor(total / n)
    local rem = total % n
    for i, e in ipairs(ents) do
        local amount = base + (i <= rem and 1 or 0)
        if amount > 0 then
            local taken = take_from_player(player, item, amount)
            if taken > 0 then
                local inserted = e.insert({ name = item, count = taken })
                if inserted < taken then
                    return_to_player(player, item, taken - inserted)
                end
                if inserted > 0 then
                    player.create_local_flying_text({
                        text = '+' .. inserted,
                        position = e.position,
                        color = FLY_COLOR,
                    })
                end
            end
        end
    end
end
Event.add(de.on_selected_entity_changed, function(event)
    if not is_active_for(event.player_index) then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local cursor = player.cursor_stack
    if not cursor or not cursor.valid_for_read then return end
    if cursor.quality and cursor.quality.name ~= 'normal' then return end 
    local selected = player.selected
    if not is_eligible(selected, cursor.name) then return end
    if blocked_by_antigrief(player, selected) then return end 
    if not selected.unit_number then return end 
    local cache = get_cache(player.index)
    cache.selectedEvent = {
        unit = selected.unit_number,
        tick = event.tick,
        item = cursor.name,
        itemCount = selected.get_item_count(cursor.name),
        cursorStackCount = cursor.count,
    }
end)
Event.add(de.on_player_fast_transferred, function(event)
    if not is_active_for(event.player_index) then return end
    if not event.from_player then return end 
    if event.is_split then return end         
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local entity = event.entity
    if not entity or not entity.valid then return end
    local cache = get_cache(player.index)
    local se = cache.selectedEvent
    if not se or not se.item or se.unit ~= entity.unit_number then return end
    local age = event.tick - se.tick
    if age < 0 or age > SNAP_WINDOW then return end
    if not is_eligible(entity, se.item) then return end
    if blocked_by_antigrief(player, entity) then return end 
    cache.item = se.item
    cache.itemCount = entity.get_item_count(se.item) - se.itemCount 
    cache.cursorStackCount = se.cursorStackCount
    register_distr(player, cache)
    if not already_listed(cache, entity) then
        cache.entities[#cache.entities + 1] = entity
    end
    give_back(entity, player, cache)
end)
Event.add(de.on_tick, function(event)
    local ed = storage.even_distribution
    if not ed or next(ed.distrEvents) == nil then return end
    local batch = ed.distrEvents[event.tick]
    if not batch then return end
    for player_index, cache in pairs(batch) do
        local player = game.get_player(player_index)
        if player and player.valid and is_active_for(player_index) then
            distribute(player, cache)
        end
        reset_cache(cache)
    end
    ed.distrEvents[event.tick] = nil
end)
Event.add(de.on_player_left_game, function(event)
    local ed = storage.even_distribution
    if not ed then return end
    local cache = ed.cache[event.player_index]
    if not cache then return end
    if cache.applyTick and ed.distrEvents[cache.applyTick] then
        ed.distrEvents[cache.applyTick][event.player_index] = nil
    end
    reset_cache(cache)
end)
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.is_user_enabled(index)
    return is_user_enabled(index)
end
function Public.set_user_enabled(index, enabled)
    ensure_storage()
    storage.even_distribution.user_disabled[index] = (not enabled) or nil
    return enabled and true or false
end
function Public.toggle_user(index)
    return Public.set_user_enabled(index, not is_user_enabled(index))
end
return Public
