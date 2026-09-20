local Event = require 'lib.event'
local Config = require 'lib.config'
local DebugLog = require 'lib.debug_log'
local Antigrief = require 'lib.antigrief'
local de = defines.events
local TOGGLE_ID = 'turret_filler'
local DEFAULT_AMOUNT = 5
local MIN_AMOUNT = 1
local MAX_AMOUNT = 100
local ROBOT_RANGE = 40
local PREFERRED_DEFAULT_AMMO = 'firearm-magazine'
local FLY_COLOR = { r = 0.8, g = 0.2, b = 0.2 }
local VANILLA_FALLBACK = { 'firearm-magazine', 'piercing-rounds-magazine', 'uranium-rounds-magazine' }
local Public = {}
local catalog
local function build_catalog()
    local list = {}
    local ok, err = pcall(function()
        local categories = {}
        for _, proto in pairs(prototypes.get_entity_filtered({ { filter = 'type', type = 'ammo-turret' } })) do
            local params = proto.attack_parameters
            local accepted = params and params.ammo_categories
            if accepted then
                for _, category in pairs(accepted) do
                    categories[category] = true
                end
            end
        end
        for name, item in pairs(prototypes.get_item_filtered({ { filter = 'type', type = 'ammo' } })) do
            local category = item.ammo_category
            if category and categories[category.name] and not item.hidden then
                list[#list + 1] = { name = name, category = category.name, order = item.order }
            end
        end
    end)
    if not ok or #list == 0 then
        if not ok then
            log('[turret_filler] odczyt prototypów amunicji nie powiódł się (' .. tostring(err) .. ') — fallback na magazynki vanilla.')
        end
        list = {}
        for i, name in ipairs(VANILLA_FALLBACK) do
            if prototypes.item[name] then
                list[#list + 1] = { name = name, category = 'bullet', order = tostring(i) }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    local index = {}
    for i, entry in ipairs(list) do
        index[entry.name] = i
    end
    catalog = {
        list = list,
        index = index,
        default = index[PREFERRED_DEFAULT_AMMO] and PREFERRED_DEFAULT_AMMO or (list[1] and list[1].name) or nil,
    }
    if DebugLog.is_enabled() then
        DebugLog.log('[turret_filler] katalog amunicji: %d pozycji, default=%s', #list, tostring(catalog.default))
        for i, entry in ipairs(list) do
            DebugLog.log('[turret_filler]   %d. %s (category=%s order=%s)', i, entry.name, entry.category, entry.order)
        end
    end
end
local function get_catalog()
    if not catalog then
        build_catalog()
    end
    return catalog
end
local function ensure_storage()
    if not storage.turret_filler then
        storage.turret_filler = { players = {} }
    end
end
Event.on_init(ensure_storage)
Event.on_configuration_changed(ensure_storage)
local function read_user(index)
    local tf = storage.turret_filler
    return tf and tf.players[index] or nil
end
local function write_user(index)
    ensure_storage()
    local players = storage.turret_filler.players
    local user = players[index]
    if not user then
        user = {}
        players[index] = user
    end
    return user
end
local function effective(index)
    local user = read_user(index)
    local cat = get_catalog()
    local enabled, amount, ammo, lower = true, DEFAULT_AMOUNT, nil, false
    if user then
        enabled = user.enabled ~= false
        amount = user.amount or DEFAULT_AMOUNT
        ammo = user.ammo
        lower = user.lower_allowed and true or false
    end
    if not (ammo and cat.index[ammo]) then
        ammo = cat.default
    end
    return enabled, amount, ammo, lower
end
local function main_inventory_of(player)
    local character = player.character
    if character and character.valid then
        return character.get_main_inventory()
    end
    return player.get_main_inventory()
end
local function pick_ammo(player, inventory, turret, chosen, lower_allowed)
    local cat = get_catalog()
    local i = cat.index[chosen]
    if not i then
        return nil
    end
    local category = cat.list[i].category
    while i >= 1 and cat.list[i].category == category do
        local name = cat.list[i].name
        if Antigrief.is_ammo_blocked_for(player, name) then
            DebugLog.log('[turret_filler]   pomijam "%s": zablokowana graczowi przez antigrief (untrusted).', name)
        elseif inventory.get_item_count(name) <= 0 then
            DebugLog.log('[turret_filler]   pomijam "%s": brak w main inventory (jakość normal).', name)
        elseif not turret.can_insert({ name = name, count = 1 }) then
            DebugLog.log('[turret_filler]   pomijam "%s": turret "%s" jej nie przyjmuje (inna kategoria / pełny).', name, turret.name)
        else
            return name
        end
        if not lower_allowed then
            break
        end
        i = i - 1
    end
    return nil
end
local function transfer_ammo(player, turret)
    local enabled, amount, chosen, lower_allowed = effective(player.index)
    if not enabled then
        DebugLog.log('[turret_filler]   BAIL: gracz "%s" ma filler wyłączony dla siebie.', player.name)
        return
    end
    if not chosen then
        DebugLog.log('[turret_filler]   BAIL: pusty katalog amunicji (brak ammo-turretów / amunicji w tej instalacji).')
        return
    end
    local inventory = main_inventory_of(player)
    if not inventory then
        DebugLog.log('[turret_filler]   BAIL: gracz "%s" nie ma main inventory (kontroler bez postaci).', player.name)
        return
    end
    local item = pick_ammo(player, inventory, turret, chosen, lower_allowed)
    if not item then
        DebugLog.log('[turret_filler]   KONIEC: nic do włożenia (wybór="%s", lower_allowed=%s).', chosen, tostring(lower_allowed))
        return
    end
    local wanted = math.min(inventory.get_item_count(item), amount)
    local inserted = turret.insert({ name = item, count = wanted })
    if inserted <= 0 then
        DebugLog.log('[turret_filler]   KONIEC: insert("%s" x%d) = 0 mimo can_insert.', item, wanted)
        return
    end
    local removed = inventory.remove({ name = item, count = inserted })
    if removed < inserted then
        turret.remove_item({ name = item, count = inserted - removed })
        log('[turret_filler] rozjazd insert/remove dla "' .. item .. '" (inserted=' .. inserted ..
            ', removed=' .. removed .. ') — nadwyżka cofnięta z turreta.')
        inserted = removed
    end
    DebugLog.log('[turret_filler]   OK: %d x "%s" → turret "%s" (gracz "%s").', inserted, item, turret.name, player.name)
    if inserted > 0 and player.surface.index == turret.surface.index then
        player.create_local_flying_text({
            text = '-' .. inserted .. ' [item=' .. item .. ']',
            position = turret.position,
            color = FLY_COLOR,
        })
    end
end
local function is_fillable(entity)
    return entity and entity.valid and entity.type == 'ammo-turret'
end
local function on_built_entity(event)
    local turret = event.entity
    if not is_fillable(turret) then return end
    if not Config.is_enabled(TOGGLE_ID) then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    DebugLog.log('[turret_filler] on_built: "%s" przez gracza "%s".', turret.name, player.name)
    transfer_ammo(player, turret)
end
local function on_robot_built_entity(event)
    local turret = event.entity
    if not is_fillable(turret) then return end
    if not Config.is_enabled(TOGGLE_ID) then return end
    local player = turret.last_user
    if not (player and player.valid and player.connected) then return end
    DebugLog.log('[turret_filler] on_robot_built: "%s", last_user="%s".', turret.name, player.name)
    if player.physical_surface_index ~= turret.surface.index then
        DebugLog.log('[turret_filler]   BAIL: postać gracza na innej powierzchni.')
        return
    end
    local body, target = player.physical_position, turret.position
    local dx, dy = body.x - target.x, body.y - target.y
    if dx * dx + dy * dy > ROBOT_RANGE * ROBOT_RANGE then
        DebugLog.log('[turret_filler]   BAIL: postać dalej niż %d kafli od turreta.', ROBOT_RANGE)
        return
    end
    transfer_ammo(player, turret)
end
Event.add(de.on_built_entity, on_built_entity)
Event.add(de.on_robot_built_entity, on_robot_built_entity)
Event.add(de.on_player_removed, function(event)
    local tf = storage.turret_filler
    if tf then
        tf.players[event.player_index] = nil
    end
end)
function Public.is_enabled()
    return Config.is_enabled(TOGGLE_ID)
end
function Public.get_settings(index)
    local enabled, amount, ammo, lower = effective(index)
    return { enabled = enabled, amount = amount, ammo = ammo, lower_allowed = lower }
end
function Public.get_amount_bounds()
    return MIN_AMOUNT, MAX_AMOUNT
end
function Public.get_selectable_ammo(player)
    local names = {}
    for _, entry in ipairs(get_catalog().list) do
        if not Antigrief.is_ammo_blocked_for(player, entry.name) then
            names[#names + 1] = entry.name
        end
    end
    return names
end
function Public.set_user_enabled(index, enabled)
    local user = write_user(index)
    if enabled then
        user.enabled = nil
    else
        user.enabled = false
    end
end
function Public.set_amount(index, value)
    value = math.floor(tonumber(value) or DEFAULT_AMOUNT)
    if value < MIN_AMOUNT then value = MIN_AMOUNT elseif value > MAX_AMOUNT then value = MAX_AMOUNT end
    write_user(index).amount = value
    return value
end
function Public.set_ammo(index, name)
    if name and not get_catalog().index[name] then
        name = nil
    end
    write_user(index).ammo = name
end
function Public.set_lower_allowed(index, allowed)
    write_user(index).lower_allowed = allowed and true or nil
end
return Public
